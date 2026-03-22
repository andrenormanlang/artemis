class DailyLunarEmailJob < ApplicationJob
  queue_as :default

  def perform
    User.find_each do |user|
      email = user.email
      @moon_data = MoonData.find_by(latitude: user.latitude,
                                  longitude: user.longitude,
                                  created_at: DateTime.now.beginning_of_day..DateTime.now.end_of_day)
      if @moon_data.nil?
        api_response = MoonApiService.new(DateTime.now, { "lat" => user.latitude,
                                                        "lon" => user.longitude,
                                                        "include_visuals" => true,
                                                        "include_zodiac" => true,
                                                        "include_special" => true }).call

        # Handle API failures gracefully — skip this user and continue
        if api_response.nil? || (api_response.is_a?(Hash) && (api_response[:error].present? || api_response["error"].present?))
          Rails.logger.error("DailyLunarEmailJob: Moon API error for #{user.email}: #{api_response.inspect}")
          next
        end

        presenter = MoonData::Index.new(api_response.with_indifferent_access, latitude: user.latitude, longitude: user.longitude).present
        @moon_data = MoonData.create(presenter)
      end
      # Send mail immediately when the job runs (works for both inline and background workers)
      UserDataMailer.daily_moon_email(user, @moon_data).deliver_now
    end
  end
end
