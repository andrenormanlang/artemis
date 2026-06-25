class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", ENV.fetch("SMTP_USERNAME", "from@example.com"))
  layout "mailer"

  private

  # Host/protocol for *_url helpers in mailers. Read from APP_HOST, but fall
  # back to the known public host so a missing/empty env var can't raise
  # "Missing host to link to" and 500 the request.
  def app_url_options
    raw = ENV["APP_HOST"].to_s.strip
    raw = "artemis-daily-lunar-reminder.onrender.com" if raw.empty?
    {
      host: raw.sub(%r{\Ahttps?://}i, "").chomp("/"),
      protocol: raw.match?(/\Ahttp:\/\//i) ? "http" : "https"
    }
  end
end
