# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CheckDepositsController#index", type: :request do
  let(:event) { create(:event, :with_positive_balance) }
  let(:user) { create(:user) }

  before do
    create(:organizer_position_invite, :accepted, event:, user:)
    session = create(:user_session, user:, verified: true, expiration_at: 1.hour.from_now)
    allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(session)
  end

  it "links each deposit to its ledger item" do
    check_deposit = CheckDeposit.create!(
      event:,
      created_by: user,
      amount_cents: 25_00,
      front: { io: file_fixture("receipt.png").open, filename: "front.png", content_type: "image/png" },
      back: { io: file_fixture("receipt.png").open, filename: "back.png", content_type: "image/png" }
    )

    get event_check_deposits_path(event)

    expect(response).to have_http_status(:ok)

    hrefs = Nokogiri::HTML(response.body).css("a.stretched-link").map { |a| a["href"] }

    expect(hrefs).to include(ledger_item_path(check_deposit.reload.ledger_item))
    expect(hrefs).not_to include(hcb_code_path(check_deposit.local_hcb_code))
  end

  it "opens each deposit in the transaction popover" do
    check_deposit = CheckDeposit.create!(
      event:,
      created_by: user,
      amount_cents: 25_00,
      front: { io: file_fixture("receipt.png").open, filename: "front.png", content_type: "image/png" },
      back: { io: file_fixture("receipt.png").open, filename: "back.png", content_type: "image/png" }
    )

    get event_check_deposits_path(event)

    link = Nokogiri::HTML(response.body).at_css("a.stretched-link[href='#{ledger_item_path(check_deposit.reload.ledger_item)}']")

    expect(link["data-behavior"]).to eq("modal_trigger")
    expect(link["data-modal"]).to eq("shared_popover")
    expect(link["data-popover-title"]).to eq("Check deposit of $25.00")
    expect(link["data-popover-src"]).to eq(check_deposit.local_hcb_code.popover_path)
    expect(link["data-popover-state-url"]).to eq(hcb_code_path(check_deposit.local_hcb_code))
  end
end
