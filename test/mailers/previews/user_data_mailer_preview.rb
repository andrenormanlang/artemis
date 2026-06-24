class UserDataMailerPreview < ActionMailer::Preview
  def lunar_phase_email_nova
    UserDataMailer.lunar_phase_email(sample_user, sample_moon_data(
      phase: "Lua Nova",
      raw_phase: "new_moon",
      days_until_full_moon: 15,
      days_until_new_moon: 0
    ))
  end

  def lunar_phase_email_quarto_crescente
    UserDataMailer.lunar_phase_email(sample_user, sample_moon_data(
      phase: "Primeiro Quarto",
      raw_phase: "first_quarter",
      days_until_full_moon: 7,
      days_until_new_moon: 22
    ))
  end

  def lunar_phase_email_cheia
    UserDataMailer.lunar_phase_email(sample_user, sample_moon_data(
      phase: "Lua Cheia",
      raw_phase: "full_moon",
      days_until_full_moon: 0,
      days_until_new_moon: 15,
      special_moon: "super lua"
    ))
  end

  def lunar_phase_email_quarto_minguante
    UserDataMailer.lunar_phase_email(sample_user, sample_moon_data(
      phase: "Último Quarto",
      raw_phase: "last_quarter",
      days_until_full_moon: 22,
      days_until_new_moon: 7
    ))
  end

  # Default preview — alias para lua cheia
  def lunar_phase_email
    lunar_phase_email_cheia
  end

  private

  def sample_user
    User.new(name: "Luna Tester", email: "preview@example.com")
  end

  def sample_moon_data(overrides = {})
    raw_phase = overrides.delete(:raw_phase) || "full_moon"

    MoonData.new({
      phase: "Lua Cheia",
      sign: "Virgem",
      special_moon: "Nenhuma lua especial",
      days_until_full_moon: 0,
      days_until_new_moon: 15,
      latitude: -23.5505,
      longitude: -46.6333,
      api_response: { "phase" => { "name" => raw_phase }, "preview" => true }
    }.merge(overrides))
  end
end
