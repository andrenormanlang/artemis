class MoonData < ApplicationRecord
  validates :latitude, presence: true
  validates :longitude, presence: true
  validates :api_response, presence: true

  # Orientação de leitura de tarô derivada da fase atual (não persistida).
  # Usa o nome bruto da fase guardado em api_response e, na falta dele,
  # cai no padrão de MoonData::TarotGuidance.
  def tarot_guidance
    MoonData::TarotGuidance.for(raw_phase_name)
  end

  def tarot_title
    tarot_guidance[:title]
  end

  def tarot_body
    tarot_guidance[:body]
  end

  def raw_phase_name
    return nil unless api_response.is_a?(Hash)

    api_response.dig("phase", "name") || api_response.dig(:phase, :name)
  end
end
