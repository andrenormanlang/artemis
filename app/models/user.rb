class User < ApplicationRecord
  has_secure_token :confirmation_token
  has_secure_token :unsubscribe_token

  # Coordenadas padrão (São Paulo) para quem se inscreve sem informar local.
  # A fase lunar é global, então isto só afeta detalhes secundários (signo etc.).
  DEFAULT_LATITUDE = -23.5505
  DEFAULT_LONGITUDE = -46.6333

  before_validation :normalize_email

  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { case_sensitive: false }

  # Apenas inscritos confirmados e que não cancelaram recebem o boletim.
  scope :subscribed, -> { where.not(confirmed_at: nil).where(unsubscribed_at: nil) }

  def confirmed?
    confirmed_at.present?
  end

  def unsubscribed?
    unsubscribed_at.present?
  end

  def confirm!
    update!(confirmed_at: Time.current, unsubscribed_at: nil)
  end

  def unsubscribe!
    update!(unsubscribed_at: Time.current)
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase.presence
  end
end
