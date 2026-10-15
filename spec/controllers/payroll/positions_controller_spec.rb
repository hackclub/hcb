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
