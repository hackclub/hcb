# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Event::ApplicationsController admin approval and activation", type: :request do
  let(:admin) { create(:user, :make_admin, verified: true) }

  before do
    session = create(:user_session, user: admin, verified: true, expiration_at: 1.hour.from_now)
    allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(session)
  end

  it "doesn't activate an application that hasn't been approved" do
    application = create(:event_application, aasm_state: "under_review")

    expect_any_instance_of(Event::Application).not_to receive(:activate_event!)

    post admin_activate_application_path(application), params: { risk_level: "zero" }

    expect(response).to redirect_to(application_path(application))
    expect(flash[:error]).to eq("Approve this application before activating it.")
    expect(application.reload.event).to be_nil
  end

  # An admin can sign for HCB from the contracts queue before approving. Approving afterward
  # must not try to hand the already-signed HCB party to someone else.
  it "approves a teen application whose HCB party already signed" do
    applicant = create(:user)
    application = create(:event_application, user: applicant, teen_led: true, aasm_state: "under_review")
    allow(User).to receive(:system_user).and_return(create(:user, :make_admin, email: User::SYSTEM_USER_EMAIL))
    allow_any_instance_of(Contract::Party).to receive(:sync_with_docuseal)
    Contract::FiscalSponsorship.create!(contractable: application, include_videos: false)
    hcb_party = application.reload.contract.party(:hcb)
    hcb_party.update_column(:aasm_state, "signed")
    original_signer = hcb_party.user

    post admin_approve_application_path(application)

    expect(response).to redirect_to(contract_party_path(hcb_party))
    expect(application.reload).to be_approved
    expect(hcb_party.reload.user).to eq(original_signer)
  end
end
