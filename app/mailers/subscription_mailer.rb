class SubscriptionMailer < ApplicationMailer
  def confirmation(user)
    @user = user
    @confirm_url = confirm_subscription_url(token: user.confirmation_token)
    mail(to: user.email, subject: "🌙 Confirme sua inscrição no Boletim Lunar")
  end
end
