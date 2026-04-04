require 'rails_helper'

RSpec.describe MoonApiService, type: :service, vcr: true do
  describe "#call" do
    let(:date) { Time.new(2026, 4, 17, 21, 30, 0, "+02:00") }
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
      fake_request = double("FaradayRequest", headers: {})
      captured_params = nil

      allow(fake_request).to receive(:params=) { |value| captured_params = value }
      allow(fake_conn).to receive(:get).and_yield(fake_request).and_return(fake_resp)
      allow(Faraday).to receive(:new).and_return(fake_conn)

      service = MoonApiService.new(date, params)
      response = service.call

      expect(response).to be_a(Hash)
      expect(response).to have_key("phase")
      expect(response).to have_key("moon_visual")
      expect(response).to have_key("zodiac")
      expect(response).to have_key("special_moon")
      expect(captured_params).to include("date" => "2026-04-17T21:30:00")
    end
  end
end
