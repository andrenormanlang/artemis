require 'rails_helper'

RSpec.describe MoonApiService, type: :service, vcr: true do
  describe "#call" do
    let(:params) do
      {
        "lat" => "40.7128",
        "lon" => "-74.0060",
        "include_visuals" => true,
        "include_zodiac" => true,
        "include_special" => true
      }
    end

    it "returns moon data for the given parameters" do
      expected_response = {
        "phase" => { "name" => "full_moon" },
        "moon_visual" => {},
        "zodiac" => { "sign" => "Aries" },
        "special_moon" => { "labels" => [] }
      }

      # Stub Faraday to avoid external HTTP in CI
      fake_conn = double("FaradayConnection")
      fake_resp = double("FaradayResponse", body: expected_response)
      allow(fake_conn).to receive(:get).and_return(fake_resp)
      allow(Faraday).to receive(:new).and_return(fake_conn)

      service = MoonApiService.new(DateTime.now, params)
      response = service.call

      expect(response).to be_a(Hash)
      expect(response).to have_key("phase")
      expect(response).to have_key("moon_visual")
      expect(response).to have_key("zodiac")
      expect(response).to have_key("special_moon")
    end
  end
end
