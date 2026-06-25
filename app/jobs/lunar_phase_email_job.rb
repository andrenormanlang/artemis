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

    gate = phase_gate(ref_time)
    if gate.nil?
      Rails.logger.error("LunarPhaseEmailJob: skipping run — could not determine today's phase")
      return
    end

    unless gate[:email_day]
      Rails.logger.info("LunarPhaseEmailJob: no principal phase or special moon on #{ref_date} (phase=#{gate[:phase_name].inspect}); nothing to send")
      return
    end

    phase_key = gate[:phase_name].presence || "special_moon"
    Rails.logger.info("LunarPhaseEmailJob: phase day on #{ref_date} (phase=#{phase_key}, special=#{gate[:special]}); sending boletim")

    # Only confirmed, non-unsubscribed recipients (double opt-in).
    User.subscribed.find_each do |user|
      send_for(user, ref_time, ref_date, phase_key)
    end
  end

  private

  # Decide se hoje é um dia de envio. Faz UMA chamada à API (local de
  # referência) e lê o nome bruto da fase + rótulos de lua especial.
  def phase_gate(ref_time)
    api_response = MoonApiService.new(ref_time, {
                                        "lat" => reference_latitude,
                                        "lon" => reference_longitude,
                                        "include_visuals" => true,
                                        "include_zodiac" => true,
                                        "include_special" => true
                                      }).call

    return nil if api_response.nil? || (api_response.is_a?(Hash) && (api_response[:error].present? || api_response["error"].present?))

    data = api_response.with_indifferent_access
    phase_name = data.dig(:phase, :name).to_s
    special = Array(data.dig(:special_moon, :labels)).any?
    principal = PRINCIPAL_PHASES.include?(phase_name.strip.gsub(" ", "_").downcase)

    { phase_name: phase_name, special: special, email_day: principal || special }
  rescue => e
    Rails.logger.error("LunarPhaseEmailJob: phase gate failed: #{e.class}: #{e.message}")
    nil
  end

  def send_for(user, ref_time, ref_date, phase_key)
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

      presenter = MoonData::Index.new(api_response.with_indifferent_access, reference_date: ref_date, latitude: user.latitude, longitude: user.longitude).present
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
