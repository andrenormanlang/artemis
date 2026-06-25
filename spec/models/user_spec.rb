require "rails_helper"

RSpec.describe User, type: :model do
  before { User.delete_all }

  it "requires a present, well-formed email" do
    expect(User.new(email: "")).not_to be_valid
    expect(User.new(email: "not-an-email")).not_to be_valid
    expect(User.new(email: "ok@example.com")).to be_valid
  end

  it "normalizes the email (strip + downcase)" do
    user = User.create!(email: "  Foo@Example.COM ")
    expect(user.email).to eq("foo@example.com")
  end

  it "enforces case-insensitive uniqueness" do
    User.create!(email: "dup@example.com")
    expect(User.new(email: "DUP@EXAMPLE.COM")).not_to be_valid
  end

  it "generates confirmation and unsubscribe tokens on create" do
    user = User.create!(email: "t@example.com")
    expect(user.confirmation_token).to be_present
    expect(user.unsubscribe_token).to be_present
  end

  describe ".subscribed" do
    it "includes only confirmed, non-unsubscribed users" do
      confirmed = User.create!(email: "c@example.com", confirmed_at: Time.current)
      User.create!(email: "pending@example.com")
      gone = User.create!(email: "g@example.com", confirmed_at: Time.current, unsubscribed_at: Time.current)

      expect(User.subscribed).to contain_exactly(confirmed)
      expect(User.subscribed).not_to include(gone)
    end
  end

  it "#confirm! marks confirmed and clears unsubscribe" do
    user = User.create!(email: "x@example.com", unsubscribed_at: Time.current)
    user.confirm!
    expect(user.reload.confirmed?).to be true
    expect(user.unsubscribed?).to be false
  end

  it "#unsubscribe! marks unsubscribed" do
    user = User.create!(email: "y@example.com", confirmed_at: Time.current)
    user.unsubscribe!
    expect(user.reload.unsubscribed?).to be true
  end
end
