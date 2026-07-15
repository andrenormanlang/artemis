require "rails_helper"

RSpec.describe LunarPhaseEmailJob, type: :job do
  # Start from a clean users table so delivery counts are deterministic
  # (rolled back by transactional fixtures after each example).
  let!(:user) do
    User.delete_all
    # Confirmed subscriber — only these receive the boletim.
    User.create!(name: "Luna", email: "luna@example.com", latitude: -23.5505, longitude: -46.6333,
                 confirmed_at: Time.current)
  end

  def api_response(phase_name:, labels: [], next_phases: {})
    {
      "phase" => { "name" => phase_name },
      "moon_visual" => {},
      "zodiac" => { "sign" => "Aries" },
      "special_moon" => { "labels" => labels },
      "next_phases" => next_phases
    }
  end

  def stub_api(response)
    allow_any_instance_of(MoonApiService).to receive(:call).and_return(response)
  end

  before do
    ActionMailer::Base.deliveries.clear
    # No real waiting between API retry attempts in tests
    allow_any_instance_of(described_class).to receive(:sleep)
  end

  context "on a principal phase day" do
    it "sends the phase email" do
      stub_api(api_response(phase_name: "full_moon"))

      expect { described_class.new.perform }.to change { ActionMailer::Base.deliveries.size }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include("Boletim Lunar")
    end
  end

  context "when a principal phase instant falls later today but the API name is not principal" do
    it "sends, presenting the day's principal phase" do
      zone = Time.find_zone!("Europe/Stockholm")
      instant = zone.now.change(hour: 21, min: 49)
      stub_api(api_response(phase_name: "Waning Gibbous",
                            next_phases: { "last_quarter" => instant.utc.iso8601 }))

      expect { described_class.new.perform }.to change { ActionMailer::Base.deliveries.size }.by(1)
      expect(ActionMailer::Base.deliveries.last.subject).to include("Último Quarto")
    end
  end

  context "when the principal phase instant already passed earlier today" do
    it "detects it via the start-of-day query and sends" do
      zone = Time.find_zone!("Europe/Stockholm")
      morning_instant = zone.now.change(hour: 10, min: 16)

      now_response = api_response(phase_name: "Waxing Crescent",
                                  next_phases: { "new_moon" => (morning_instant + 29.days).utc.iso8601 })
      day_start_response = api_response(phase_name: "Waning Crescent",
                                        next_phases: { "new_moon" => morning_instant.utc.iso8601 })

      gate_service = instance_double(MoonApiService, call: now_response)
      day_start_service = instance_double(MoonApiService, call: day_start_response)
      per_user_service = instance_double(MoonApiService, call: now_response)
      allow(MoonApiService).to receive(:new).and_return(gate_service, day_start_service, per_user_service)

      expect { described_class.new.perform }.to change { ActionMailer::Base.deliveries.size }.by(1)
      expect(ActionMailer::Base.deliveries.last.subject).to include("Lua Nova")
    end
  end

  context "when the start-of-day check is rate limited then succeeds" do
    it "retries and still sends (regression for the 2026-07-14 missed new moon)" do
      zone = Time.find_zone!("Europe/Stockholm")
      morning_instant = zone.now.change(hour: 10, min: 16)

      now_response = api_response(phase_name: "Waxing Crescent",
                                  next_phases: { "new_moon" => (morning_instant + 29.days).utc.iso8601 })
      day_start_response = api_response(phase_name: "Waning Crescent",
                                        next_phases: { "new_moon" => morning_instant.utc.iso8601 })
      rate_limited = { "error" => "HTTP 429", "status" => 429, "retry_after" => 1 }

      gate_service = instance_double(MoonApiService, call: now_response)
      throttled_service = instance_double(MoonApiService, call: rate_limited)
      day_start_service = instance_double(MoonApiService, call: day_start_response)
      per_user_service = instance_double(MoonApiService, call: now_response)
      allow(MoonApiService).to receive(:new)
        .and_return(gate_service, throttled_service, day_start_service, per_user_service)

      expect { described_class.new.perform }.to change { ActionMailer::Base.deliveries.size }.by(1)
      expect(ActionMailer::Base.deliveries.last.subject).to include("Lua Nova")
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
