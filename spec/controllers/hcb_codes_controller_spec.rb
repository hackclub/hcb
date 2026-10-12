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

    context "for a Wise transfer whose pending transaction is not grouped under its HCB code" do
      let(:wise_transfer) do
        WiseTransfer.create!(
          event:,
          user: create(:user),
          amount_cents: 100_00,
          currency: "GBP",
          recipient_country: "GB",
          recipient_name: "Fiona Hackworth",
          recipient_email: "fiona@example.com",
          payment_for: "Speaker fee",
          # Set so the after_create hook skips generate_quote!, which would
          # otherwise reach for a live exchange rate.
          quoted_usd_amount_cents: 130_00
        )
      end
      let(:hcb_code) { wise_transfer.local_hcb_code }

      before do
        # Reproduces production rows where the CPT's hcb_code write failed, so
        # HcbCode#pt is nil even though the transfer and its CPT both exist.
        wise_transfer.canonical_pending_transaction.update_column(:hcb_code, nil)
      end

      it "renders and still warns that the USD amount may change" do
        get :show, params: { id: hcb_code.hashid }

        expect(response).to be_successful
        expect(response.body).to include("might change")
      end

      it "drops the warning once a canonical transaction has settled the transfer" do
        create(:canonical_transaction, amount_cents: -130_00).update_column(:hcb_code, hcb_code.hcb_code)

        get :show, params: { id: hcb_code.hashid }

        expect(response).to be_successful
        expect(response.body).not_to include("might change")
      end
    end
  end

  describe "GET #show inside a turbo frame" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }
    let(:cpt) { create(:canonical_pending_transaction) }
    let(:hcb_code) { cpt.local_hcb_code }
    let(:message) { "Marked no/lost receipt on that transaction." }

    before do
      create(:canonical_pending_event_mapping, canonical_pending_transaction: cpt, event:)
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)
      request.headers["Turbo-Frame"] = "shared_popover_body"
    end

    # What the flash hash carries into the *next* request.
    def flash_carried_over
      session["flash"].to_h["flashes"]
    end

    it "renders the flash inside the frame, flags it, and doesn't repeat it on the next page" do
      get(:edit, params: { id: hcb_code.hashid }, flash: { success: message })

      expect(response.body).to include(message)
      expect(response.headers["X-Flash"]).to eq("true")
      expect(flash_carried_over).to be_blank
    end

    it "keeps the flash on a frame response that never renders it" do
      get(:edit, params: { id: hcb_code.hashid, inline: "true" }, flash: { success: message })

      expect(response.body).not_to include(message)
      expect(response.headers).not_to include("X-Flash")
      expect(flash_carried_over).to include("success" => message)
    end

    it "only sends the no/lost link back to the frame it was rendered in" do
      user.make_admin!

      get(:show, params: { id: hcb_code.hashid, frame: true })
      expect(response.body).to include(CGI.escapeHTML(receiptable_mark_no_or_lost_path(receiptable_type: "HcbCode", receiptable_id: hcb_code.id, return_to: request.original_url)))

      request.headers["Turbo-Frame"] = nil
      get(:show, params: { id: hcb_code.hashid })
      expect(response.body).to include("No/lost receipt?")
      expect(response.body).not_to include("return_to")
    end
  end
end
