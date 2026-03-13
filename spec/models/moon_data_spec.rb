RSpec.describe MoonData, type: :model do
  it "is valid with valid attributes" do
    moon_data = MoonData.new(latitude: 40.7128, longitude: -74.0060, api_response: { phase: "Full Moon" })
    expect(moon_data).to be_valid
  end

  it "is not valid without a latitude" do
    moon_data = MoonData.new(longitude: -74.0060, api_response: { phase: "Full Moon" })
    expect(moon_data).not_to be_valid
  end

  it "is not valid without a longitude" do
    moon_data = MoonData.new(latitude: 40.7128, api_response: { phase: "Full Moon" })
    expect(moon_data).not_to be_valid
  end

  it "is not valid without an api_response" do
    moon_data = MoonData.new(latitude: 40.7128, longitude: -74.0060)
    expect(moon_data).not_to be_valid
  end
end
