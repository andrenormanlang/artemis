require "faraday"

# ActionMailer delivery method that sends through Brevo's transactional email
# HTTPS API (https://developers.brevo.com). Used on hosts that block outbound
# SMTP ports (e.g. Render) and where the SES sandbox can't reach unverified
# recipients. Free tier: 300 emails/day; you only verify the *sender*, then
# can send to any recipient.
#
# Enabled with MAIL_DELIVERY_METHOD=brevo + BREVO_API_KEY.
class BrevoDelivery
  API_URL = "https://api.brevo.com/v3/smtp/email".freeze

  def initialize(settings = {})
    @api_key = settings[:api_key].presence || ENV["BREVO_API_KEY"]
  end

  def deliver!(mail)
    raise ArgumentError, "BREVO_API_KEY is not set" if @api_key.blank?

    response = Faraday.post(API_URL) do |req|
      req.headers["api-key"]      = @api_key
      req.headers["Content-Type"] = "application/json"
      req.headers["Accept"]       = "application/json"
      req.body = payload(mail).to_json
    end

    return response if response.success?

    raise "Brevo delivery failed: HTTP #{response.status} #{response.body}"
  end

  private

  def payload(mail)
    body = {
      sender: sender(mail),
      to: Array(mail.to).map { |email| { email: email } },
      subject: mail.subject.to_s
    }

    html = mail.html_part&.body&.decoded
    text = mail.text_part&.body&.decoded
    html ||= mail.body.decoded unless mail.multipart?

    body[:htmlContent] = html if html.present?
    body[:textContent] = text if text.present?
    body
  end

  def sender(mail)
    email = Array(mail.from).first
    name  = mail[:from]&.display_names&.compact&.first
    sender = { email: email }
    sender[:name] = name if name.present?
    sender
  end
end
