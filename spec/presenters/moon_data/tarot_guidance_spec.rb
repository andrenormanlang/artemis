require "rails_helper"

RSpec.describe MoonData::TarotGuidance do
  it "returns specific guidance for each principal phase" do
    expect(described_class.for("new_moon")[:title]).to eq("Defina intenções")
    expect(described_class.for("first_quarter")[:title]).to eq("Hora de agir")
    expect(described_class.for("full_moon")[:title]).to eq("Verdades reveladas")
    expect(described_class.for("last_quarter")[:title]).to eq("Solte e encerre")
  end

  it "normalizes spaced / cased names" do
    expect(described_class.for("Full Moon")).to eq(described_class.for("full_moon"))
  end

  it "falls back to the default for unknown phases" do
    expect(described_class.for("not_a_phase")).to eq(described_class::DEFAULT)
    expect(described_class.for(nil)).to eq(described_class::DEFAULT)
  end

  describe "MoonData#tarot_* derivation" do
    it "reads the raw phase name from api_response" do
      moon = MoonData.new(latitude: 1, longitude: 2, api_response: { "phase" => { "name" => "full_moon" } })
      expect(moon.tarot_title).to eq("Verdades reveladas")
    end

    it "falls back to default when api_response has no phase name" do
      moon = MoonData.new(latitude: 1, longitude: 2, api_response: { "preview" => true })
      expect(moon.tarot_guidance).to eq(MoonData::TarotGuidance::DEFAULT)
    end
  end
end
