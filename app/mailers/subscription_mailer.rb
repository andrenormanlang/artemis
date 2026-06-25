class SubscriptionMailer < ApplicationMailer
  def confirmation(user)
    @user = user
    @confirm_url = confirm_subscription_url(token: user.confirmation_token, **app_url_options)
    mail(to: user.email, subject: "🌙 Confirme sua inscrição no Boletim Lunar")
  end
end
