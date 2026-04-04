class DailyLunarEmailJob < ApplicationJob
  queue_as :default

  def perform
    stockholm_today = Time.find_zone!("Europe/Stockholm").today

    User.find_each do |user|
      unless claim_delivery_slot(user, stockholm_today)
        Rails.logger.info("DailyLunarEmailJob: skipping duplicate send for #{user.email} on #{stockholm_today}")
        next
      end

      @moon_data = MoonData.find_by(latitude: user.latitude,
                                  longitude: user.longitude,
                                  created_at: stockholm_today.beginning_of_day..stockholm_today.end_of_day)

      if @moon_data.nil?
        api_response = MoonApiService.new(Time.find_zone!("Europe/Stockholm").now, {
                                            "lat" => user.latitude,
                                            "lon" => user.longitude,
                                            "include_visuals" => true,
                                            "include_zodiac" => true,
                                            "include_special" => true
                                          }).call

        # Handle API failures gracefully — skip this user and continue
        if api_response.nil? || (api_response.is_a?(Hash) && (api_response[:error].present? || api_response["error"].present?))
          Rails.logger.error("DailyLunarEmailJob: Moon API error for #{user.email}: #{api_response.inspect}")
          release_delivery_slot(user, stockholm_today)
          next
        end

        presenter = MoonData::Index.new(api_response.with_indifferent_access, reference_date: stockholm_today, latitude: user.latitude, longitude: user.longitude).present
        @moon_data = MoonData.create(presenter)
      end

      Rails.logger.info("DailyLunarEmailJob: phase for #{user.email} = #{@moon_data.phase.inspect}")
      UserDataMailer.daily_moon_email(user, @moon_data).deliver_now
    rescue => e
      release_delivery_slot(user, stockholm_today)
      Rails.logger.error("DailyLunarEmailJob: send failed for #{user.email}: #{e.class}: #{e.message}")
      raise e
    end
  end

  private

  def claim_delivery_slot(user, stockholm_today)
    Sidekiq.redis do |redis|
      redis.set(delivery_key(user, stockholm_today), "1", nx: true, ex: 2.days.to_i)
    end
  rescue => e
    Rails.logger.warn("DailyLunarEmailJob: dedupe unavailable for #{user.email}: #{e.class}: #{e.message}")
    true
  end

  def release_delivery_slot(user, stockholm_today)
    Sidekiq.redis do |redis|
      redis.del(delivery_key(user, stockholm_today))
    end
  rescue => e
    Rails.logger.warn("DailyLunarEmailJob: failed to release dedupe key for #{user.email}: #{e.class}: #{e.message}")
  end

  def delivery_key(user, stockholm_today)
    "daily_lunar_email:#{stockholm_today.iso8601}:user:#{user.id}"
  end
end
