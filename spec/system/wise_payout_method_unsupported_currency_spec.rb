# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Wise payout method in an unsupported currency", type: :system do
  let(:user) { create(:user) }
  let(:reason) { "Wise transfers in CNY are currently not supported. Please send an international wire instead." }

  before do
    session = create(:user_session, user:, expiration_at: 1.day.from_now, verified: true)
    allow_any_instance_of(ApplicationController).to receive(:find_current_session).and_return(session)

    # Payout methods created before CNY was disabled.
    details = create(:wise_transfer_payout_method_details, currency: "CNY", account_type: "alipay", alipay_id: "fiona@example.com", allow_unsupported_recipient: true)
    user.personal_legal_entity.payout_methods.create!(default: true, details:)
  end

  it "flags the method as unavailable and explains why when editing it" do
    visit settings_payouts_path

    row = find("[data-payout-methods-row]")
    expect(row).to have_css(".badge[aria-label='#{reason}']", text: "Unavailable")

    row.click_on "Edit"

    expect(row).to have_select("user[payout_method_wise_transfer][currency]", selected: "CNY (unavailable)")
    expect(row).to have_text(reason)
  end
end
