# frozen_string_literal: true

require "rails_helper"

# Covers the shared `public_activity/common` layout, which links any trackable
# that has a ledger item to that ledger item.
RSpec.describe "public_activity/wire/_create" do
  let(:user) { create(:user) }
  let(:wire) { create(:wire, user:, event: create(:event, :with_positive_balance)) }

  before do
    def view.current_user = nil
  end

  before do
    # Wires look up their recipient's bank at Column on creation.
    stub_request(:get, /api\.column\.com\/institutions\/.*/)
      .to_return(status: 200, body: '{"country_code": "DE"}', headers: { "Content-Type" => "application/json" })
  end

  it "links the activity to the wire's ledger item" do
    activity = PublicActivity::Activity.create!(trackable: wire.reload, key: "wire.create", owner: user)

    render partial: "public_activity/wire/create", locals: { activity:, p: {}, current_user: user }
    hrefs = Nokogiri::HTML(rendered).css("a").map { |a| a["href"] }

    expect(wire.reload.ledger_item).to be_present
    expect(hrefs).to include(ledger_item_path(wire.ledger_item))
    expect(hrefs).not_to include(a_string_matching(/\/hcb\//))
  end
end
