class UserDataMailerPreview < ActionMailer::Preview
  def daily_moon_email_nova
    UserDataMailer.daily_moon_email(sample_user, sample_moon_data(
      phase: "Lua nova",
      days_until_full_moon: 15,
      days_until_new_moon: 0
    ))
  end

  def daily_moon_email_crescente
    UserDataMailer.daily_moon_email(sample_user, sample_moon_data(
      phase: "Lua crescente",
      days_until_full_moon: 11,
      days_until_new_moon: 4
    ))
  end

  def daily_moon_email_quarto_crescente
    UserDataMailer.daily_moon_email(sample_user, sample_moon_data(
      phase: "Quarto crescente",
      days_until_full_moon: 7,
      days_until_new_moon: 22
    ))
  end

  def daily_moon_email_gibosa_crescente
    UserDataMailer.daily_moon_email(sample_user, sample_moon_data(
      phase: "Gibosa crescente",
      days_until_full_moon: 4,
      days_until_new_moon: 19
    ))
  end

  def daily_moon_email_cheia
    UserDataMailer.daily_moon_email(sample_user, sample_moon_data(
      phase: "Lua cheia",
      days_until_full_moon: 0,
      days_until_new_moon: 15,
      special_moon: "Super Lua"
    ))
  end

  def daily_moon_email_gibosa_minguante
    UserDataMailer.daily_moon_email(sample_user, sample_moon_data(
      phase: "Gibosa minguante",
      days_until_full_moon: 26,
      days_until_new_moon: 11
    ))
  end

  def daily_moon_email_quarto_minguante
    UserDataMailer.daily_moon_email(sample_user, sample_moon_data(
      phase: "Quarto minguante",
      days_until_full_moon: 22,
      days_until_new_moon: 7
    ))
  end

  def daily_moon_email_minguante
    UserDataMailer.daily_moon_email(sample_user, sample_moon_data(
      phase: "Lua minguante",
      days_until_full_moon: 19,
      days_until_new_moon: 4
    ))
  end

  # Default preview — alias for gibosa crescente
  def daily_moon_email
    daily_moon_email_gibosa_crescente
  end

  private

  def sample_user
    User.new(name: "Luna Tester", email: "preview@example.com")
  end

  def sample_moon_data(overrides = {})
    MoonData.new({
      phase: "Gibosa crescente",
      sign: "Virgem",
      special_moon: "Nenhuma lua especial",
      days_until_full_moon: 4,
      days_until_new_moon: 19,
      latitude: 59.3293,
      longitude: 18.0686,
      api_response: { preview: true }
    }.merge(overrides))
  end
end
