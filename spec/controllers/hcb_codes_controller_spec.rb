# frozen_string_literal: true

require "rails_helper"

RSpec.describe HcbCodesController, type: :controller do
  include SessionSupport
  render_views

  describe "GET #show" do
    let(:event) {
      event = create(:event)
      create(:canonical_pending_transaction, amount_cents: 1000, event:, fronted: true)
      event
    }
    let(:ach_transfer) { create(:ach_transfer, event:) }
    let(:hcb_code) { ach_transfer.local_hcb_code }

    before { create_session(create(:user, :make_auditor), verified: true) }

    it "shows the Process button after the transfer can no longer be canceled" do
      ach_transfer.update_column(:aasm_state, "deposited")

      get :show, params: { id: hcb_code.hashid }

      expect(response).to be_successful
      expect(response.body).to include(%(action="#{ach_start_approval_admin_path(ach_transfer)}"))
      expect(response.body).not_to include("Cancel transfer")
    end

    it "links each CPT to its own page" do
      cpt = hcb_code.canonical_pending_transactions.sole

      get :show, params: { id: hcb_code.hashid }

      expect(response.body).to include(%(href="#{canonical_pending_transaction_path(cpt)}">CPT #{cpt.id}</a>))
    end
  end
end
