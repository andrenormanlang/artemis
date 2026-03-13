class UserDataMailer < ApplicationMailer
  def daily_moon_email(user, moon_data)
    @user = user
    @moon_data = moon_data

    mail(to: @user.email, subject: "🌙 Boletim Lunar - #{Date.current.strftime('%d/%m/%Y')}")
  end
end