class LunarPhaseEmailJob < ApplicationJob
  queue_as :default

  # As quatro fases principais têm data exata; só nelas (ou em uma lua
  # especial) enviamos o boletim. Nos demais dias o job termina sem enviar.
  PRINCIPAL_PHASES = %w[new_moon first_quarter full_moon last_quarter].freeze

  # Local de referência apenas para descobrir a fase do dia (a fase é
  # global; a localização não altera o nome da fase). Sobrescrevível por ENV.
  REFERENCE_LATITUDE  = -23.5505
  REFERENCE_LONGITUDE = -46.6333

  def perform
    zone = Time.find_zone!(ENV.fetch("DELIVERY_TIME_ZONE", "Europe/Stockholm"))
    ref_time = zone.now
    ref_date = ref_time.to_date

    gate = phase_gate(zone, ref_time, ref_date)
    if gate.nil?
      Rails.logger.error("LunarPhaseEmailJob: skipping run — could not determine today's phase")
      return
    end

    unless gate[:email_day]
      Rails.logger.info("LunarPhaseEmailJob: no principal phase or special moon on #{ref_date} (phase=#{gate[:phase_name].inspect}); nothing to send")
      return
    end

    phase_key = gate[:phase_key].presence || "special_moon"
    Rails.logger.info("LunarPhaseEmailJob: phase day on #{ref_date} (phase=#{phase_key}, special=#{gate[:special]}); sending boletim")

    # Only confirmed, non-unsubscribed recipients (double opt-in).
    User.subscribed.find_each do |user|
      send_for(user, ref_time, ref_date, gate[:phase_key], phase_key)
    end
  end

  private

  # Decide se hoje é um dia de envio. O nome instantâneo da fase na API só é
  # confiável perto do instante exato (quartos quase nunca aparecem), então
  # além do nome verificamos se o INSTANTE de alguma fase principal
  # (next_phases) cai na data de hoje no fuso de entrega.
  def phase_gate(zone, ref_time, ref_date)
    data = fetch_reference_data(ref_time)
    return nil if data.nil?

    phase_name = data.dig(:phase, :name).to_s
    special = Array(data.dig(:special_moon, :labels)).any?

    normalized = phase_name.strip.gsub(" ", "_").downcase
    phase_key =
      if PRINCIPAL_PHASES.include?(normalized)
        normalized
      else
        principal_phase_today(zone, ref_date, data)
      end

    { phase_key: phase_key, phase_name: phase_name, special: special,
      email_day: phase_key.present? || special }
  rescue => e
    Rails.logger.error("LunarPhaseEmailJob: phase gate failed: #{e.class}: #{e.message}")
    nil
  end

  # Alguma fase principal acontece hoje? Primeiro olha os next_phases da
  # consulta atual (instantes ainda por vir hoje); se nada, consulta o início
  # do dia para enxergar instantes que já passaram (ex.: lua nova de manhã).
  def principal_phase_today(zone, ref_date, ref_data)
    found = principal_instant_on(ref_data[:next_phases], zone, ref_date)
    return found if found

    day_start = zone.local(ref_date.year, ref_date.month, ref_date.day, 0, 5)
    day_data = fetch_reference_data(day_start)
    day_data && principal_instant_on(day_data[:next_phases], zone, ref_date)
  end

  def principal_instant_on(next_phases, zone, ref_date)
    return nil if next_phases.blank?

    PRINCIPAL_PHASES.find do |phase|
      timestamp = next_phases[phase]
      next false if timestamp.blank?

      begin
        zone.parse(timestamp.to_s)&.to_date == ref_date
      rescue ArgumentError, TypeError
        false
      end
    end
  end

  def fetch_reference_data(time)
    api_response = MoonApiService.new(time, {
                                        "lat" => reference_latitude,
                                        "lon" => reference_longitude,
                                        "include_visuals" => true,
                                        "include_zodiac" => true,
                                        "include_special" => true
                                      }).call

    return nil if api_response.nil? || (api_response.is_a?(Hash) && (api_response[:error].present? || api_response["error"].present?))

    api_response.with_indifferent_access
  end

  def send_for(user, ref_time, ref_date, principal_phase, phase_key)
    unless claim_delivery_slot(user, ref_date, phase_key)
      Rails.logger.info("LunarPhaseEmailJob: skipping duplicate send for #{user.email} on #{ref_date} (#{phase_key})")
      return
    end

    moon_data = MoonData.find_by(latitude: user.latitude,
                                 longitude: user.longitude,
                                 created_at: ref_date.beginning_of_day..ref_date.end_of_day)

    if moon_data.nil?
      api_response = MoonApiService.new(ref_time, {
                                          "lat" => user.latitude,
                                          "lon" => user.longitude,
                                          "include_visuals" => true,
                                          "include_zodiac" => true,
                                          "include_special" => true
                                        }).call

      # Falha de API: pula este usuário e libera o slot para reprocessar depois.
      if api_response.nil? || (api_response.is_a?(Hash) && (api_response[:error].present? || api_response["error"].present?))
        Rails.logger.error("LunarPhaseEmailJob: Moon API error for #{user.email}: #{api_response.inspect}")
        release_delivery_slot(user, ref_date, phase_key)
        return
      end

      presenter = MoonData::Index.new(api_response.with_indifferent_access,
                                      reference_date: ref_date,
                                      latitude: user.latitude,
                                      longitude: user.longitude,
                                      phase_name_override: principal_phase).present
      moon_data = MoonData.create(presenter)
    end

    Rails.logger.info("LunarPhaseEmailJob: phase for #{user.email} = #{moon_data.phase.inspect}")
    UserDataMailer.lunar_phase_email(user, moon_data).deliver_now
  rescue => e
    release_delivery_slot(user, ref_date, phase_key)
    Rails.logger.error("LunarPhaseEmailJob: send failed for #{user.email}: #{e.class}: #{e.message}")
    raise e
  end

  def claim_delivery_slot(user, ref_date, phase_key)
    Sidekiq.redis do |redis|
      redis.set(delivery_key(user, ref_date, phase_key), "1", nx: true, ex: 2.days.to_i)
    end
  rescue => e
    Rails.logger.warn("LunarPhaseEmailJob: dedupe unavailable for #{user.email}: #{e.class}: #{e.message}")
    true
  end

  def release_delivery_slot(user, ref_date, phase_key)
    Sidekiq.redis do |redis|
      redis.del(delivery_key(user, ref_date, phase_key))
    end
  rescue => e
    Rails.logger.warn("LunarPhaseEmailJob: failed to release dedupe key for #{user.email}: #{e.class}: #{e.message}")
  end

  def delivery_key(user, ref_date, phase_key)
    "lunar_phase_email:#{ref_date.iso8601}:#{phase_key}:user:#{user.id}"
  end

  def reference_latitude
    ENV.fetch("REFERENCE_LATITUDE", REFERENCE_LATITUDE).to_f
  end

  def reference_longitude
    ENV.fetch("REFERENCE_LONGITUDE", REFERENCE_LONGITUDE).to_f
  end
end
