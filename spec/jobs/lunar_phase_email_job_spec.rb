require "rails_helper"

RSpec.describe LunarPhaseEmailJob, type: :job do
  # Start from a clean users table so delivery counts are deterministic
  # (rolled back by transactional fixtures after each example).
  let!(:user) do
    User.delete_all
    User.create!(name: "Luna", email: "luna@example.com", latitude: -23.5505, longitude: -46.6333)
  end

  def api_response(phase_name:, labels: [])
    {
      "phase" => { "name" => phase_name },
      "moon_visual" => {},
      "zodiac" => { "sign" => "Aries" },
      "special_moon" => { "labels" => labels },
      "next_phases" => {}
    }
  end

  def stub_api(response)
    allow_any_instance_of(MoonApiService).to receive(:call).and_return(response)
  end

  before { ActionMailer::Base.deliveries.clear }

  context "on a principal phase day" do
    it "sends the phase email" do
      stub_api(api_response(phase_name: "full_moon"))

      expect { described_class.new.perform }.to change { ActionMailer::Base.deliveries.size }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include("Boletim Lunar")
    end
  end

  context "on a non-principal phase day with no special moon" do
    it "does not send anything" do
      stub_api(api_response(phase_name: "waxing_crescent"))

      expect { described_class.new.perform }.not_to change { ActionMailer::Base.deliveries.size }
    end
  end

  context "on a special-moon day even without a principal phase" do
    it "still sends" do
      stub_api(api_response(phase_name: "waning_gibbous", labels: [ "is_supermoon" ]))

      expect { described_class.new.perform }.to change { ActionMailer::Base.deliveries.size }.by(1)
    end
  end

  context "when the phase gate API call fails" do
    it "does not send and does not raise" do
      stub_api({ "error" => "boom" })

      expect { described_class.new.perform }.not_to change { ActionMailer::Base.deliveries.size }
    end
  end
end
