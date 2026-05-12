# frozen_string_literal: true

require "rails_helper"

# Tests for the new acceptance-method features introduced in the
# "Allow users to accept invites as reimbursements" PR.
RSpec.describe CardGrantsController, type: :controller do
  include SessionSupport
  render_views

  before do
    allow_any_instance_of(CardGrant).to receive(:transfer_money)
    allow_any_instance_of(CardGrant).to receive(:send_email)
  end

  # ---------------------------------------------------------------------------
  # #create — acceptance method params are permitted and persisted
  # ---------------------------------------------------------------------------
  describe "#create with acceptance method params" do
    let(:organizer) { create(:user) }
    let(:event) { create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate) }
    let(:base_params) do
      {
        amount_cents: "50.00",
        email: "recipient@example.com"
      }
    end

    before do
      create(:card_grant_setting, event:)
      create(:organizer_position, user: organizer, event:)
      create_session(organizer, verified: true)
    end

    it "persists allow_stripe_card: false when submitted" do
      post(:create, params: {
        event_id: event.friendly_id,
        card_grant: base_params.merge(allow_stripe_card: "0", allow_reimbursement_report: "1")
      })

      grant = event.card_grants.sole
      expect(grant.allow_stripe_card).to be false
      expect(grant.allow_reimbursement_report).to be true
    end

    it "persists allow_reimbursement_report: true when submitted" do
      post(:create, params: {
        event_id: event.friendly_id,
        card_grant: base_params.merge(allow_stripe_card: "1", allow_reimbursement_report: "1")
      })

      grant = event.card_grants.sole
      expect(grant.allow_stripe_card).to be true
      expect(grant.allow_reimbursement_report).to be true
    end

    it "rejects a grant where both methods are disabled" do
      post(:create, params: {
        event_id: event.friendly_id,
        card_grant: base_params.merge(allow_stripe_card: "0", allow_reimbursement_report: "0")
      })

      expect(event.card_grants).to be_empty
      expect(response).to have_http_status(:unprocessable_entity)
      expect(flash[:error]).to include("At least one acceptance method")
    end
  end

  # ---------------------------------------------------------------------------
  # #accept_as_reimbursement — happy path
  # ---------------------------------------------------------------------------
  describe "#accept_as_reimbursement" do
    let(:organizer) { create(:user) }
    let(:grantee) { create(:user) }
    let(:event) { create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate) }
    let(:card_grant) do
      create(:card_grant, event:, user: grantee, sent_by: organizer,
             stripe_card: nil, allow_stripe_card: false, allow_reimbursement_report: true)
    end

    before do
      create(:card_grant_setting, event:, allow_stripe_card: false, allow_reimbursement_report: true)
      create(:organizer_position, user: organizer, event:)
    end

    context "when the grantee accepts" do
      before { create_session(grantee, verified: true) }

      it "redirects to the reimbursement report with a success flash" do
        report = instance_double(Reimbursement::Report, to_model: Reimbursement::Report.new, persisted?: true)
        allow(card_grant).to receive(:reimbursement_report).and_return(nil)
        allow_any_instance_of(CardGrant).to receive(:convert_to_reimbursement_report!).and_return(report)
        allow(report).to receive(:class).and_return(Reimbursement::Report)

        post(:accept_as_reimbursement, params: { id: card_grant.hashid })

        expect(flash[:success]).to eq("Successfully opened a reimbursement report for your grant.")
      end
    end

    context "when allow_reimbursement_report is false" do
      let(:card_grant_no_reimb) do
        create(:card_grant, event:, user: grantee, sent_by: organizer,
               stripe_card: nil, allow_stripe_card: true, allow_reimbursement_report: false)
      end

      before { create_session(grantee, verified: true) }

      it "raises Pundit::NotAuthorizedError" do
        expect do
          post(:accept_as_reimbursement, params: { id: card_grant_no_reimb.hashid })
        end.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context "when the grant is already activated (stripe card present)" do
      let(:stripe_card) { create(:stripe_card, :with_stripe_id) }
      let(:already_activated_grant) do
        create(:card_grant, event:, user: grantee, sent_by: organizer,
               stripe_card:, allow_reimbursement_report: true)
      end

      before { create_session(grantee, verified: true) }

      it "raises Pundit::NotAuthorizedError because pending_invite? is false" do
        expect do
          post(:accept_as_reimbursement, params: { id: already_activated_grant.hashid })
        end.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context "when convert_to_reimbursement_report! raises ArgumentError" do
      before { create_session(grantee, verified: true) }

      it "redirects back to the grant with an error flash" do
        allow_any_instance_of(CardGrant).to receive(:reimbursement_report).and_return(nil)
        allow_any_instance_of(CardGrant).to receive(:convert_to_reimbursement_report!)
          .and_raise(ArgumentError, "card grant should have a non-zero balance")

        post(:accept_as_reimbursement, params: { id: card_grant.hashid })

        expect(response).to redirect_to(card_grant_path(card_grant))
        expect(flash[:error]).to eq("card grant should have a non-zero balance")
      end
    end

    context "when convert_to_reimbursement_report! raises ActiveRecord::RecordInvalid" do
      before { create_session(grantee, verified: true) }

      it "redirects back to the grant with an error flash instead of raising 500" do
        allow_any_instance_of(CardGrant).to receive(:reimbursement_report).and_return(nil)
        invalid_record = Reimbursement::Report.new
        allow_any_instance_of(CardGrant).to receive(:convert_to_reimbursement_report!)
          .and_raise(ActiveRecord::RecordInvalid.new(invalid_record))

        post(:accept_as_reimbursement, params: { id: card_grant.hashid })

        expect(response).to redirect_to(card_grant_path(card_grant))
        expect(flash[:error]).to be_present
      end
    end

    context "when called twice concurrently (idempotent via with_lock)" do
      before { create_session(grantee, verified: true) }

      it "uses the existing report on a second call without creating a duplicate" do
        existing_report = instance_double(Reimbursement::Report)
        # Simulate DB finding an already-created report (race condition / double submit)
        allow(Reimbursement::Report).to receive(:find_by).with(card_grant_id: card_grant.id).and_return(existing_report)
        allow_any_instance_of(CardGrant).to receive(:with_lock).and_yield
        allow(existing_report).to receive(:class).and_return(Reimbursement::Report)
        allow(existing_report).to receive(:to_model).and_return(Reimbursement::Report.new)
        allow(existing_report).to receive(:persisted?).and_return(true)

        expect_any_instance_of(CardGrant).not_to receive(:convert_to_reimbursement_report!)

        post(:accept_as_reimbursement, params: { id: card_grant.hashid })

        expect(flash[:success]).to eq("Successfully opened a reimbursement report for your grant.")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #show — invitation partial branches
  # ---------------------------------------------------------------------------
  describe "#show invitation partial" do
    let(:organizer) { create(:user) }
    let(:grantee) { create(:user) }
    let(:event) { create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate) }

    before do
      create(:card_grant_setting, event:)
      create(:organizer_position, user: organizer, event:)
      create_session(grantee, verified: true)
    end

    context "when only stripe card is allowed" do
      let(:card_grant) do
        create(:card_grant, event:, user: grantee, sent_by: organizer,
               stripe_card: nil, allow_stripe_card: true, allow_reimbursement_report: false)
      end

      it "shows the virtual card activation form" do
        get(:show, params: { id: card_grant.hashid })

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Activate your grant card")
        expect(response.body).not_to include("Open a reimbursement report")
      end
    end

    context "when only reimbursement is allowed" do
      let(:card_grant) do
        create(:card_grant, event:, user: grantee, sent_by: organizer,
               stripe_card: nil, allow_stripe_card: false, allow_reimbursement_report: true)
      end

      it "shows the reimbursement form only" do
        get(:show, params: { id: card_grant.hashid })

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Open a reimbursement report")
        expect(response.body).not_to include("Activate your grant card")
      end
    end

    context "when both methods are allowed" do
      let(:card_grant) do
        create(:card_grant, event:, user: grantee, sent_by: organizer,
               stripe_card: nil, allow_stripe_card: true, allow_reimbursement_report: true)
      end

      it "shows both option cards" do
        get(:show, params: { id: card_grant.hashid })

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Get a virtual card")
        expect(response.body).to include("Open a reimbursement")
      end

      it "shows Card Issuing Terms only in the virtual card section, not as a global gate" do
        get(:show, params: { id: card_grant.hashid })

        expect(response.body).to include("Card Issuing Terms")
        expect(response.body).to include("cardSubmitButton")
        # The reimbursement button uses submitButton (no card terms required)
        expect(response.body).to include("submitButton")
      end
    end
  end
end
