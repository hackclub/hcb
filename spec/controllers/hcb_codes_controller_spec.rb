# frozen_string_literal: true

require "rails_helper"

RSpec.describe HcbCodesController, type: :controller do
  include SessionSupport
  render_views

  describe "GET #show" do
    # Part of adding shared_commentable support for Invoice-linked HcbCodes —
    # this page's comment list/form used to assume shared_commentable? meant
    # "this is a disbursement leg" and would crash on an invoice-type HcbCode.
    it "renders an invoice-type HcbCode's comments, including the Invoice's own, without crashing" do
      expect_any_instance_of(Sponsor).to receive(:create_stripe_customer).and_return(true)
      invoice = create(:invoice)
      hcb_code = invoice.local_hcb_code
      event = invoice.event
      member_user = create(:user)
      create(:organizer_position, event:, user: member_user, role: :member)
      create_session(member_user, verified: true)

      # HcbCodePolicy#show? relies on HcbCode#events (derived from its
      # canonical (pending) transactions), not the invoice's own event.
      cpt = create(:canonical_pending_transaction)
      cpt.update_column(:hcb_code, hcb_code.hcb_code)
      create(:canonical_pending_event_mapping, canonical_pending_transaction: cpt, event:)

      hcb_code_comment = create(:comment, commentable: hcb_code, user: member_user, content: "comment on the hcb code")
      invoice_comment = create(:comment, commentable: invoice, user: member_user, content: "comment on the invoice")

      get :show, params: { id: hcb_code.hcb_code }

      expect(response).to be_successful
      expect(response.body).to include(hcb_code_comment.content)
      expect(response.body).to include(invoice_comment.content)
    end

    it "renders a disbursement leg's counterparty comment link without crashing" do
      disbursement = create(:disbursement)
      outgoing = HcbCode.find_or_create_by(hcb_code: disbursement.outgoing_hcb_code)
      incoming = HcbCode.find_or_create_by(hcb_code: disbursement.incoming_hcb_code)
      member_user = create(:user)
      create(:organizer_position, event: disbursement.source_event, user: member_user, role: :member)
      # Also a member of the destination event, so HcbCodePolicy#show? passes
      # for the counterparty's HcbCode too (the link is gated on that).
      create(:organizer_position, event: disbursement.event, user: member_user, role: :member)
      create_session(member_user, verified: true)

      # HcbCodePolicy#show? relies on HcbCode#events (derived from its
      # canonical (pending) transactions) — needed for both legs, since the
      # counterparty link also runs `policy(counterparty_hcb_code).show?`.
      outgoing_cpt = create(:canonical_pending_transaction)
      outgoing_cpt.update_column(:hcb_code, outgoing.hcb_code)
      create(:canonical_pending_event_mapping, canonical_pending_transaction: outgoing_cpt, event: disbursement.source_event)

      incoming_cpt = create(:canonical_pending_transaction)
      incoming_cpt.update_column(:hcb_code, incoming.hcb_code)
      create(:canonical_pending_event_mapping, canonical_pending_transaction: incoming_cpt, event: disbursement.event)

      create(:comment, commentable: incoming, user: member_user, content: "comment from the destination org")

      get :show, params: { id: outgoing.hcb_code }

      expect(response).to be_successful
      expect(response.body).to include("other comment")
    end
  end
end
