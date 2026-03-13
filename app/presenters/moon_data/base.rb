# require 'facets'

class MoonData::Base

  def initialize(moon_data, latitude: nil, longitude: nil)
    @moon_data = moon_data
    @latitude = latitude
    @longitude = longitude
  end

  def present
    raise "present must be created"
  end

  private

  def translate_special_moon(special_moon)
    return "Nenhuma lua especial" if special_moon[:labels].empty?

    special_moon_translation = lambda do |moon|
      translations = {
        is_supermoon: "super lua",
        is_micromoon: "micro lua",
        is_blue_moon: "lua azul",
        is_black_moon: "lua negra",
        is_harvest_moon: "lua da colheita",
        is_hunter_moon: "lua da caça"
      }
      translations[moon.to_sym]
    end

    special_moon.map do |key, label|
      special_moon_translation.call(key) if label == true
    end.to_compact.join(", ")
  end

  def translate_sign(sign)
    translations = {
      aries: "Áries",
      taurus: "Touro",
      gemini: "Gêmeos",
      cancer: "Câncer",
      leo: "Leão",
      virgo: "Virgem",
      libra: "Libra",
      scorpio: "Escorpião",
      sagittarius: "Sagitário",
      capricorn: "Capricórnio",
      aquarius: "Aquário",
      pisces: "Peixes"
    }
    translations[sign.downcase.to_sym] || sign
  end

  def translate_phase(phase)
    translations = {
      new_moon: "Lua Nova",
      waxing_crescent: "Crescente Crescente",
      first_quarter: "Primeiro Quarto",
      waxing_gibbous: "Gibosa Crescente",
      full_moon: "Lua Cheia",
      waning_gibbous: "Gibosa Minguante",
      last_quarter: "Último Quarto",
      waning_crescent: "Crescente Minguante"
    }
    translations[phase.gsub(" ","_").downcase.to_sym] || phase
  end
end