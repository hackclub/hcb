# frozen_string_literal: true

require "rails_helper"

# The receipt form listens for pastes on the whole page only where it is the
# page's single upload target. Popovers stack many forms on one list page, and
# each would upload the same paste.
RSpec.describe "Receipt form page-wide paste", type: :request do
  let(:cpt) { create(:canonical_pending_transaction, event: create(:event)) }
  let(:hcb_code) { cpt.local_hcb_code }
  let(:ct) { create(:canonical_transaction, event: create(:event), transaction_source: create(:raw_plaid_transaction)) }

  before do
    session = create(:user_session, user: create(:user, :make_admin), expiration_at: 1.hour.from_now)
    allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(session)
  end

  def global_paste_values
    response.parsed_body.css("[data-file-drop-global-paste-value]").map { |el| el["data-file-drop-global-paste-value"] }
  end

  {
    "HCB code"            => -> { hcb_code_path(hcb_code) },
    "ledger item"         => -> { ledger_item_path(hcb_code.ledger_item) },
    "pending transaction" => -> { canonical_pending_transaction_path(cpt) },
    "transaction"         => -> { transaction_path(ct) },
    "admin transaction"   => -> { transaction_admin_path(ct) },
    "disbursement"        => -> {
      disbursement = create(:disbursement)
      HcbCode.find_or_create_by!(hcb_code: disbursement.outgoing_hcb_code).update!(ledger_item: create(:ledger_item))
      disbursement_path(disbursement)
    },
    "payment"             => -> { payment_path(create(:payment)) },
  }.each do |page, path|
    it "is on for the #{page} page" do
      get instance_exec(&path)

      expect(response).to be_successful
      expect(global_paste_values).to eq(["true"])
    end
  end

  it "is off when the HCB code renders in a popover" do
    get hcb_code_path(hcb_code, frame: true)

    expect(global_paste_values).to eq(["false"])
  end

  it "is off when the ledger item renders in a popover" do
    get ledger_item_path(hcb_code.ledger_item, frame: true)

    expect(global_paste_values).to eq(["false"])
  end
end
