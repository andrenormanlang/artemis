# Register the Brevo HTTPS-API delivery method so it can be selected with
# config.action_mailer.delivery_method = :brevo (MAIL_DELIVERY_METHOD=brevo).
ActiveSupport.on_load(:action_mailer) do
  add_delivery_method :brevo, BrevoDelivery
end
