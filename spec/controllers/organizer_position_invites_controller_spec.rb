# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrganizerPositionInvitesController do
  include SessionSupport
  render_views

  describe "#create" do
    before do
      # This is required since sending contracts defaults to the system user email for HCB's party
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
    end

    it "creates an invitation" do
      user = create(:user)
      event = create(:event, organizers: [user])

      create_session(user, verified: true)

      post(
        :create,
        params: {
          event_id: event.friendly_id,
          organizer_position_invite: {
            email: "orpheus@hackclub.com",
            role: "member",
            enable_controls: "true",
            initial_control_allowance_amount: "123.45",
          }
        }
      )

      expect(response).to redirect_to(event_team_path(event))
      expect(flash[:success]).to eq("Invite successfully sent to orpheus@hackclub.com")

      invite = event.organizer_position_invites.last
      expect(invite.sender).to eq(user)
      expect(invite.user.email).to eq("orpheus@hackclub.com")
      expect(invite.role).to eq("member")
      expect(invite.initial_control_allowance_amount_cents).to eq(123_45)
    end

    it "supports additional params for admins" do
      user = create(:user, :make_admin)
      event = create(:event, organizers: [user])

      # `Contract` makes external requests to Airtable and
      # Docuseal which we don't want to perform in this context.
      expect(ApplicationsTable).to(
        receive(:all)
          .with(filter: include(event.id.to_s))
          .and_return([])
          .once
      )
      create_docuseal_request =
        stub_request(:post, "https://api.docuseal.co/submissions")
        .to_return(
          status: 201,
          body: [{ submission_id: "STUBBED" }].to_json,
          headers: { content_type: "application/json" }
        )
      fetch_docuseal_request =
        stub_request(:get, "https://api.docuseal.co/submissions/STUBBED")
        .to_return(
          status: 200,
          body: { submitters: [{ role: "HCB", slug: "STUBBED" }, { role: "Contract Signee", slug: "STUBBED" }, { role: "Cosigner", slug: "STUBBED" }] }.to_json,
          headers: { content_type: "application/json" }
        )

      create_session(user, verified: true)

      post(
        :create,
        params: {
          event_id: event.friendly_id,
          organizer_position_invite: {
            email: "orpheus@hackclub.com",
            role: "manager",
            enable_controls: "false",
            cosigner_email: "cosigner@hackclub.com",
            include_videos: "true",
            is_signee: "true",
          }
        }
      )

      expect(create_docuseal_request).to(have_been_made.once)
      expect(fetch_docuseal_request).to(have_been_made.once)

      expect(response).to redirect_to(event_team_path(event))
      expect(flash[:success]).to eq("Invite successfully sent to orpheus@hackclub.com")

      invite = event.organizer_position_invites.last
      expect(invite.is_signee).to eq(true)

      contract = invite.contracts.sole

      expect(contract.party(:cosigner)&.email).to eq("cosigner@hackclub.com")
      expect(contract.include_videos).to eq(true)
      expect(contract.external_service).to eq("docuseal")
      expect(contract.external_id).to eq("STUBBED")
      expect(contract.party(:signee)&.external_id).to eq("STUBBED")
    end
  end

  describe "#resend_to_cosigner" do
    let(:event) { create(:event) }
    let(:invite) { create(:organizer_position_invite, event:) }

    before do
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))

      stub_request(:post, "https://api.docuseal.co/submissions")
        .to_return(
          status: 201,
          body: [{ submission_id: "STUBBED" }].to_json,
          headers: { content_type: "application/json" }
        )
      stub_request(:get, "https://api.docuseal.co/submissions/STUBBED")
        .to_return(
          status: 200,
          body: { submitters: [{ role: "HCB", slug: "STUBBED" }, { role: "Contract Signee", slug: "STUBBED" }, { role: "Cosigner", slug: "STUBBED" }] }.to_json,
          headers: { content_type: "application/json" }
        )

      invite.send_contract(cosigner_email: "old-cosigner@hackclub.com", include_videos: false)
    end

    it "resends to the same email without voiding the contract" do
      create_session(invite.user, verified: true)
      original_contract = invite.contract

      post :resend_to_cosigner, params: { id: invite.to_param, cosigner_email: "old-cosigner@hackclub.com" }

      expect(flash[:success]).to eq("Resent agreement to cosigner")
      expect(original_contract.reload).to be_sent
      expect(invite.reload.contract).to eq(original_contract)
    end

    it "voids and reissues the contract when the cosigner email changes" do
      create_session(invite.user, verified: true)
      original_contract = invite.contract

      post :resend_to_cosigner, params: { id: invite.to_param, cosigner_email: "new-cosigner@hackclub.com" }

      expect(flash[:success]).to eq("Resent agreement to cosigner")
      expect(original_contract.reload).to be_voided

      new_contract = invite.reload.contract
      expect(new_contract).not_to eq(original_contract)
      expect(new_contract.reissue_of).to eq(original_contract)
      expect(new_contract.party(:cosigner).email).to eq("new-cosigner@hackclub.com")
    end

    it "rejects the invitee's own email as the cosigner email" do
      create_session(invite.user, verified: true)

      post :resend_to_cosigner, params: { id: invite.to_param, cosigner_email: invite.user.email }

      expect(flash[:error]).to eq("You cannot use your own email as the cosigner's email")
      expect(invite.reload.contract).to be_sent
    end

    it "denies an unrelated, non-admin user" do
      other_user = create(:user)
      create_session(other_user, verified: true)
      original_contract = invite.contract

      post :resend_to_cosigner, params: { id: invite.to_param, cosigner_email: "new-cosigner@hackclub.com" }

      expect(flash[:error]).to eq("You are not authorized to perform this action.")
      expect(original_contract.reload).to be_sent
    end
  end
end
