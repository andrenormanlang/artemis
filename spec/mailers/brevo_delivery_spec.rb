require "rails_helper"

RSpec.describe BrevoDelivery do
  let(:mail) do
    Mail.new do
      from "Artemis <sender@example.com>"
      to "dest@example.com"
      subject "Confirme"
      text_part { body "texto simples" }
      html_part do
        content_type "text/html; charset=UTF-8"
        body "<p>conteudo html</p>"
      end
    end
  end

  def stub_faraday(success:, status: 201, body: "{}")
    req = double("request", headers: {})
    captured = {}
    allow(req).to receive(:body=) { |value| captured[:body] = value }
    response = double("response", success?: success, status: status, body: body)
    allow(Faraday).to receive(:post).and_yield(req).and_return(response)
    captured
  end

  it "posts a Brevo transactional email with sender, recipient, subject and both bodies" do
    captured = stub_faraday(success: true)

    described_class.new(api_key: "secret-key").deliver!(mail)

    payload = JSON.parse(captured[:body])
    expect(payload["sender"]).to eq("email" => "sender@example.com", "name" => "Artemis")
    expect(payload["to"]).to eq([ { "email" => "dest@example.com" } ])
    expect(payload["subject"]).to eq("Confirme")
    expect(payload["htmlContent"]).to include("conteudo html")
    expect(payload["textContent"]).to include("texto simples")
  end

  it "raises when the API key is missing" do
    expect { described_class.new(api_key: nil).deliver!(mail) }
      .to raise_error(ArgumentError, /BREVO_API_KEY/)
  end

  it "raises when Brevo returns a non-success response" do
    stub_faraday(success: false, status: 401, body: "unauthorized")

    expect { described_class.new(api_key: "k").deliver!(mail) }
      .to raise_error(/Brevo delivery failed: HTTP 401/)
  end
end
