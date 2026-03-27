class UserDataMailer < ApplicationMailer
  def daily_moon_email(user, moon_data)
    @user = user
    @moon_data = moon_data
    stockholm_date = Time.find_zone!("Europe/Stockholm").today.strftime("%d/%m/%Y")
    phase_name = @moon_data.phase.presence || "Seu céu de hoje"

    mail(to: @user.email, subject: "🌙 #{phase_name} • Boletim Lunar #{stockholm_date}")
  end
end
