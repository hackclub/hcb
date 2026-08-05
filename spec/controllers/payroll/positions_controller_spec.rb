# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payroll::PositionsController do
  include SessionSupport

  let(:user) { create(:user) }
  let(:event) { create(:event, organizers: [user]) }
  let(:payee) { create(:payee, event:) }

  before do
    Flipper.enable(:payments_contractors_refresh_2026_06_26, event)
    allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
    create_session(user, verified: true)
  end

  def stub_docuseal_create(submission_id: "STUBBED", status: 201)
    stub_request(:post, "https://api.docuseal.co/submissions")
      .to_return(status:, body: status == 201 ? [{ submission_id: }].to_json : "boom", headers: { content_type: "application/json" })
  end

  def stub_docuseal_fetch(submission_id: "STUBBED")
    stub_request(:get, "https://api.docuseal.co/submissions/#{submission_id}")
      .to_return(
        status: 200,
        body: { submitters: [{ role: "HCB", slug: "hcb-slug" }, { role: "Organizer", slug: "organizer-slug" }, { role: "Contractor", slug: "contractor-slug" }] }.to_json,
        headers: { content_type: "application/json" }
      )
  end

  describe "POST #create" do
    let(:position_params) do
      {
        event_id: event.slug,
        contractor: {
          payee_id: payee.hashid,
          title: "Engineer",
          rate: "25.00",
          starts_on: Date.current,
          ends_on: 3.months.from_now.to_date,
          purpose: "Build things"
        }
      }
    end

    it "creates the position and sends its contract" do
      stub_docuseal_create
      stub_docuseal_fetch

      post :create, params: position_params

      position = event.payroll_positions.last
      expect(response).to redirect_to(contract_event_payroll_position_path(event_id: event.slug, id: position.id))
      expect(position.contracts.sole).to be_sent
    end

    it "creates a fixed-amount position when the rate unit is contract" do
      stub_docuseal_create
      stub_docuseal_fetch

      position_params[:contractor][:rate_unit] = "contract"
      post :create, params: position_params

      position = event.payroll_positions.last
      expect(position).to be_fixed_rate
      expect(position.rate_label).to eq("$25.00 (fixed)")
    end

    it "normalizes custom rate units and renders them in the rate label" do
      stub_docuseal_create
      stub_docuseal_fetch

      position_params[:contractor][:rate_unit] = " Articles "
      post :create, params: position_params

      position = event.payroll_positions.last
      expect(position.rate_unit).to eq("article")
      expect(position.rate_label).to eq("$25.00 per article")
    end

    it "defaults the rate unit to hour when omitted" do
      stub_docuseal_create
      stub_docuseal_fetch

      post :create, params: position_params

      position = event.payroll_positions.last
      expect(position.rate_unit).to eq("hour")
      expect(position.rate_label).to eq("$25.00/hr")
    end

    it "redirects to edit and flashes an error when DocuSeal is unreachable, without crashing" do
      stub_docuseal_create(status: 500)

      post :create, params: position_params

      position = event.payroll_positions.last
      expect(response).to redirect_to(edit_event_payroll_position_path(event_id: event.slug, id: position.id))
      expect(flash[:error]).to be_present
      expect(position.contracts.not_voided).to be_empty
    end
  end

  describe "PATCH #update" do
    let(:position) { create(:payroll_position, payee:, rate_cents: 2500) }

    before do
      stub_docuseal_create
      stub_docuseal_fetch
      position.send_contract(organizer_user: user)
    end

    it "does not void or replace the contract when nothing contract-relevant changed" do
      original_contract = position.contracts.sole

      patch :update, params: {
        event_id: event.slug,
        id: position.id,
        contractor: { title: position.title, rate: "25.00", starts_on: position.start_date, ends_on: position.end_date, purpose: position.description }
      }

      expect(position.contracts.reload.count).to eq(1)
      expect(position.contracts.sole).to eq(original_contract)
      expect(position.contracts.sole).not_to be_voided
    end

    it "voids the in-flight contract and sends a linked replacement when the rate changes" do
      original_contract = position.contracts.sole
      stub_request(:delete, "https://api.docuseal.co/submissions/STUBBED").to_return(status: 200, body: "")
      stub_docuseal_create(submission_id: "REISSUED")
      stub_docuseal_fetch(submission_id: "REISSUED")

      patch :update, params: {
        event_id: event.slug,
        id: position.id,
        contractor: { title: position.title, rate: "50.00", starts_on: position.start_date, ends_on: position.end_date, purpose: position.description }
      }

      expect(original_contract.reload).to be_voided
      new_contract = position.contracts.not_voided.sole
      expect(new_contract.reissue_of).to eq(original_contract)
      expect(position.reload.rate_cents).to eq(5_000)
    end

    it "keeps a reissue_of link through a failed-attempt retry, instead of dropping it" do
      original_contract = position.contracts.sole
      stub_request(:delete, "https://api.docuseal.co/submissions/STUBBED").to_return(status: 200, body: "")
      stub_docuseal_create(status: 500)

      # First attempt: terms change, the old contract is voided, but the
      # resend to DocuSeal fails — nothing not-voided exists afterwards, and
      # the failed attempt itself is left voided (linked back to the original).
      patch :update, params: {
        event_id: event.slug,
        id: position.id,
        contractor: { title: position.title, rate: "50.00", starts_on: position.start_date, ends_on: position.end_date, purpose: position.description }
      }
      expect(original_contract.reload).to be_voided
      expect(position.contracts.not_voided).to be_empty
      failed_attempt = position.contracts.where.not(id: original_contract.id).sole
      expect(failed_attempt).to be_voided
      expect(failed_attempt.reissue_of).to eq(original_contract)

      # Retry with identical params (no further terms change, so nothing new
      # gets voided this time) still chains the eventual replacement off the
      # failed attempt, rather than losing the link entirely (reissue_of: nil).
      stub_docuseal_create(submission_id: "REISSUED")
      stub_docuseal_fetch(submission_id: "REISSUED")

      patch :update, params: {
        event_id: event.slug,
        id: position.id,
        contractor: { title: position.title, rate: "50.00", starts_on: position.start_date, ends_on: position.end_date, purpose: position.description }
      }

      new_contract = position.contracts.not_voided.sole
      expect(new_contract.reissue_of).to eq(failed_attempt)
    end

    it "is forbidden once the contract has been fully signed, and leaves the position untouched" do
      position.contracts.sole.update_column(:aasm_state, "signed")

      patch :update, params: {
        event_id: event.slug,
        id: position.id,
        contractor: { title: "New title", rate: "999.00", starts_on: position.start_date, ends_on: position.end_date, purpose: position.description }
      }

      expect(flash[:error]).to eq("You are not authorized to perform this action.")
      expect(position.reload.title).not_to eq("New title")
      expect(position.rate_cents).to eq(2500)
    end

    describe "changing the recipient's email" do
      # Unclaimed (no legal entity): the contractor hasn't attached their
      # identity yet, which is the only window the email is editable in.
      let(:payee) { create(:payee, event:, email: "old@example.com", legal_entity: nil) }

      def unchanged_terms
        { title: position.title, rate: "25.00", starts_on: position.start_date, ends_on: position.end_date, purpose: position.description }
      end

      it "re-addresses the existing contract instead of voiding it" do
        original_contract = position.contracts.sole

        patch :update, params: {
          event_id: event.slug,
          id: position.id,
          contractor: unchanged_terms.merge(email: "Preferred@Example.com")
        }

        expect(payee.reload.email).to eq("preferred@example.com")
        expect(position.contracts.reload.sole).to eq(original_contract)
        expect(original_contract.reload).not_to be_voided
        expect(original_contract.party(:contractor).email).to eq("preferred@example.com")
      end

      it "re-sends the agreement and says so when HCB has already countersigned" do
        position.contracts.sole.party(:hcb).mark_signed!

        expect do
          patch :update, params: {
            event_id: event.slug,
            id: position.id,
            contractor: unchanged_terms.merge(email: "preferred@example.com")
          }
        end.to have_enqueued_mail(Payroll::PositionMailer, :onboarding)

        expect(flash[:success]).to eq("Contractor updated. Their agreement has been re-sent to preferred@example.com.")
      end

      it "leaves the contract alone when the submitted email is unchanged" do
        original_contract = position.contracts.sole

        patch :update, params: {
          event_id: event.slug,
          id: position.id,
          contractor: unchanged_terms.merge(email: payee.email.upcase)
        }

        expect(position.contracts.reload.sole).to eq(original_contract)
        expect(original_contract.reload).not_to be_voided
        expect(flash[:success]).to be_nil
      end

      it "rejects a malformed email and leaves both records untouched" do
        original_contract = position.contracts.sole
        previous_email = payee.email

        patch :update, params: {
          event_id: event.slug,
          id: position.id,
          contractor: unchanged_terms.merge(email: "nope", purpose: "Something else")
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(flash[:error]).to be_present
        expect(payee.reload.email).to eq(previous_email)
        expect(position.reload.description).not_to eq("Something else")
        expect(original_contract.reload).not_to be_voided
      end

      it "is forbidden once a payment has been sent to an unmanaged recipient" do
        previous_email = payee.email
        create(:payment, :sent, payee:)

        patch :update, params: {
          event_id: event.slug,
          id: position.id,
          contractor: unchanged_terms.merge(email: "preferred@example.com")
        }

        expect(flash[:error]).to eq("You are not authorized to perform this action.")
        expect(payee.reload.email).to eq(previous_email)
        expect(position.contracts.sole.party(:contractor).email).to eq(previous_email)
      end

      it "is forbidden once the recipient has claimed the payee with a legal entity" do
        previous_email = payee.email
        payee.update!(legal_entity: create(:legal_entity))

        patch :update, params: {
          event_id: event.slug,
          id: position.id,
          contractor: unchanged_terms.merge(email: "preferred@example.com")
        }

        expect(flash[:error]).to eq("You are not authorized to perform this action.")
        expect(payee.reload.email).to eq(previous_email)
      end

      it "is forbidden for an org member who can edit terms but is not a manager" do
        member = create(:user)
        create(:organizer_position, user: member, event:, role: :member)
        create_session(member, verified: true)
        previous_email = payee.email

        patch :update, params: {
          event_id: event.slug,
          id: position.id,
          contractor: unchanged_terms.merge(email: "preferred@example.com")
        }

        expect(payee.reload.email).to eq(previous_email)
      end

      it "still allows the change for a managed recipient with sent payments" do
        payee.update!(legal_entity: create(:legal_entity, managing_event: event))
        create(:payment, :sent, payee:)

        patch :update, params: {
          event_id: event.slug,
          id: position.id,
          contractor: unchanged_terms.merge(email: "preferred@example.com")
        }

        expect(payee.reload.email).to eq("preferred@example.com")
      end

      it "records who changed the email", versioning: true do
        patch :update, params: {
          event_id: event.slug,
          id: position.id,
          contractor: unchanged_terms.merge(email: "preferred@example.com")
        }

        version = payee.reload.versions.last
        expect(version.whodunnit).to eq(user.id.to_s)
        expect(version.changeset["email"]).to eq(["old@example.com", "preferred@example.com"])
      end
    end
  end

  describe "GET #edit" do
    render_views

    let(:payee) { create(:payee, event:, legal_entity: nil) }
    let(:position) { create(:payroll_position, payee:) }

    before do
      stub_docuseal_create
      stub_docuseal_fetch
      position.send_contract(organizer_user: user)
    end

    it "offers the recipient's email for editing, saying it re-sends the agreement" do
      get :edit, params: { event_id: event.slug, id: position.id }

      expect(response.body).to include("contractor[email]")
      expect(response.body).to include("re-sends the agreement")
    end

    it "shows the email read-only once a payment has been sent" do
      create(:payment, :sent, payee:)

      get :edit, params: { event_id: event.slug, id: position.id }

      expect(response.body).not_to include("contractor[email]")
      expect(response.body).to include(payee.email)
    end

    it "shows the email read-only once the recipient has claimed the payee" do
      payee.update!(legal_entity: create(:legal_entity))

      get :edit, params: { event_id: event.slug, id: position.id }

      expect(response.body).not_to include("contractor[email]")
    end
  end

  describe "GET #show" do
    render_views

    let(:position) { create(:payroll_position, payee:) }

    it "links to the edit page" do
      get :show, params: { event_id: event.slug, id: position.id }

      expect(response.body).to include(edit_event_payroll_position_path(event_id: event.slug, id: position.id))
    end
  end

  describe "GET #contract" do
    render_views

    let(:position) { create(:payroll_position, payee:) }

    before do
      stub_docuseal_create
      stub_docuseal_fetch
    end

    it "shows the signing embed to the user who created the invite" do
      position.send_contract(organizer_user: user)

      get :contract, params: { event_id: event.slug, id: position.id }

      expect(response.body).to include("docuseal-form")
    end

    it "does not expose the signing embed to a different authorized org member" do
      other_organizer = create(:user)
      create(:organizer_position, user: other_organizer, event:, role: :manager)
      position.send_contract(organizer_user: other_organizer)

      get :contract, params: { event_id: event.slug, id: position.id }

      expect(response.body).not_to include("docuseal-form")
      expect(response.body).to include("Waiting on")
    end

    it "redirects to edit when no active contract exists yet" do
      get :contract, params: { event_id: event.slug, id: position.id }

      expect(response).to redirect_to(edit_event_payroll_position_path(event_id: event.slug, id: position.id))
      expect(flash[:error]).to be_present
    end
  end
end
