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

  describe "POST #set_category" do
    let(:event) { create(:event) }
    let(:ct) { create(:canonical_transaction, event:) }
    let(:user) { create(:user) }

    def set_category(slug)
      post(:set_category, params: { id: ct.local_hcb_code.hashid, event_id: event.slug, category_slug: slug })
    end

    it "lets members set the category on their event's transactions" do
      other_ct = create(:canonical_transaction, event: create(:event), hcb_code: ct.hcb_code)
      create(:organizer_position, user:, event:, role: :member)
      create_session(user, verified: true)

      set_category("rent")

      expect(ct.reload.category.slug).to eq("rent")
      expect(ct.category_mapping.assignment_strategy).to eq("manual")
      expect(other_ct.reload.category).to be_nil
    end

    it "does not let members set HQ-only categories" do
      create(:organizer_position, user:, event:, role: :member)
      create_session(user, verified: true)

      set_category("hcb-revenue")

      expect(ct.reload.category).to be_nil
    end

    it "does not let readers or members of another event set the category" do
      other_event = create(:event)
      create(:canonical_transaction, event: other_event, hcb_code: ct.hcb_code)
      create(:organizer_position, user:, event:, role: :reader)
      create(:organizer_position, user:, event: other_event, role: :member)
      create_session(user, verified: true)

      set_category("rent")

      expect(ct.reload.category).to be_nil
    end
  end
end
