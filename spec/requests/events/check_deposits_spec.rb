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
    expect(response.body).to include(ledger_item_path(check_deposit.reload.ledger_item))
    expect(response.body).not_to include(hcb_code_path(check_deposit.local_hcb_code))
  end
end
