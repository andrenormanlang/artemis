class MoonData::Index < MoonData::Base
  def present
    {
      phase: translate_phase(@moon_data[:phase][:name]),
      sign: translate_sign(@moon_data[:zodiac][:sign]),
      special_moon: translate_special_moon(@moon_data[:special_moon]),
      days_until_full_moon: @moon_data[:next_phases] && @moon_data[:next_phases][:full_moon] ? (Date.parse(@moon_data[:next_phases][:full_moon].to_s).to_date - Date.current).to_i : nil,
      days_until_new_moon: @moon_data[:next_phases] && @moon_data[:next_phases][:new_moon] ? (Date.parse(@moon_data[:next_phases][:new_moon].to_s).to_date - Date.current).to_i : nil,
      api_response: @moon_data,
      latitude: @latitude,
      longitude: @longitude
    }
  end
end
