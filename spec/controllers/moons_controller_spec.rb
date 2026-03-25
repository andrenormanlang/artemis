require 'rails_helper'

RSpec.describe "MoonsController", type: :request, vcr: true do
  describe "GET /index" do
    context "when location parameters are provided" do
      it "stores the location in the session and renders the index template" do
        get moon_index_path, params: { lat: "40.7128", lng: "-74.0060" }
        expect(session[:latitude]).to eq("40.7128")
        expect(session[:longitude]).to eq("-74.0060")
        expect(response).to render_template(:index)
      end
    end

    context "when location parameters are not provided but session has location" do
      before do
        session[:latitude] = "40.7128"
        session[:longitude] = "-74.0060"
      end

      it "renders the index template with last checked moon data" do
        get moon_index_path
        expect(response).to render_template(:index)
        # Additional assertions can be added here to check for @last_checked_moon data
      end
    end

    context "when no location parameters and no session location" do
      it "renders the loading_location template" do
        get moon_index_path
        expect(response).to render_template(:loading_location)
      end
    end
  end
end
