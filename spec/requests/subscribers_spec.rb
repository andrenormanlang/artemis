require "rails_helper"

RSpec.describe "Subscribers", type: :request do
  before do
    ActionMailer::Base.deliveries.clear
    User.delete_all
  end

  it "shows the signup form" do
    get new_subscriber_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Boletim Lunar")
  end

  it "creates an unconfirmed user and sends a confirmation email" do
    expect do
      post subscribers_path, params: { user: { email: "New@Example.com" } }
    end.to change(User, :count).by(1)

    user = User.last
    expect(user.email).to eq("new@example.com")
    expect(user.confirmed?).to be false

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([ "new@example.com" ])
    expect(mail.subject).to include("Confirme")
  end

  it "stores coordinates from the form when provided" do
    post subscribers_path, params: { user: { email: "geo@example.com", latitude: "55.6049", longitude: "13.0038" } }
    user = User.find_by(email: "geo@example.com")
    expect(user.latitude).to eq(55.6049)
    expect(user.longitude).to eq(13.0038)
  end

  it "falls back to default coordinates when none are provided" do
    post subscribers_path, params: { user: { email: "nogeo@example.com" } }
    user = User.find_by(email: "nogeo@example.com")
    expect(user.latitude).to eq(User::DEFAULT_LATITUDE)
    expect(user.longitude).to eq(User::DEFAULT_LONGITUDE)
  end

  it "ignores honeypot submissions" do
    expect do
      post subscribers_path, params: { user: { email: "bot@example.com" }, nickname: "spam" }
    end.not_to change(User, :count)
  end

  it "rejects an invalid email" do
    expect do
      post subscribers_path, params: { user: { email: "nope" } }
    end.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "confirms a subscription via token" do
    user = User.create!(email: "c@example.com")
    get confirm_subscription_path(token: user.confirmation_token)
    expect(user.reload.confirmed?).to be true
  end

  it "unsubscribes via token" do
    user = User.create!(email: "u@example.com", confirmed_at: Time.current)
    get unsubscribe_path(token: user.unsubscribe_token)
    expect(user.reload.unsubscribed?).to be true
  end
end
