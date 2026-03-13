class MoonData::Index < MoonData::Base
  def present
    {
      phase: translate_phase(@moon_data[:phase][:name]),
      sign: translate_sign(@moon_data[:zodiac][:sign]),
      special_moon: translate_special_moon(@moon_data[:special_moon]),
      days_until_full_moon: Date.parse(@moon_data[:next_phases][:full_moon].to_s).strftime("%Y%m%d").to_i - Time.now.strftime("%Y%m%d").to_i,
      days_until_new_moon: Date.parse(@moon_data[:next_phases][:new_moon].to_s).strftime("%Y%m%d").to_i - Time.now.strftime("%Y%m%d").to_i,
      api_response: @moon_data,
      latitude: @latitude,
      longitude: @longitude
    }
  end
end