class UserDataMailer < ApplicationMailer
  def lunar_phase_email(user, moon_data)
    @user = user
    @moon_data = moon_data
    if user.respond_to?(:unsubscribe_token) && user.unsubscribe_token.present?
      @unsubscribe_url = unsubscribe_url(token: user.unsubscribe_token, **app_url_options)
    end
    zone = Time.find_zone!(ENV.fetch("DELIVERY_TIME_ZONE", "Europe/Stockholm"))
    report_date = zone.today.strftime("%d/%m/%Y")
    phase_name = @moon_data.phase.presence || "Seu céu de hoje"

    mail(to: @user.email, subject: "🌙 #{phase_name} • Boletim Lunar #{report_date}")
  end
end
