# frozen_string_literal: true

require "rails_helper"

RSpec.describe "organizer_position_invites/show" do
  let(:signee) { create(:user) }
  let(:event) { create(:event) }
  let(:invite) { create(:organizer_position_invite, event:, user: signee) }

  let(:signed_title) { "You&#39;ve signed the contract for this organization. It&#39;s under review." }

  before do
    allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
  end

  def send_contract(cosigner: false)
    contract = Contract::FiscalSponsorship.create!(contractable: invite, include_videos: false)
    contract.parties.create!(user: signee, role: :signee)
    contract.parties.create!(external_email: "parent@example.com", role: :cosigner) if cosigner
    contract.update_column(:aasm_state, "sent")
    contract
  end

  def render_page
    assign(:invite, invite)
    assign(:organizers, invite.event.organizer_positions.includes(:user))
    render template: "organizer_position_invites/show"
    rendered
  end

  context "when the invitee has not signed" do
    it "asks them to sign it" do
      send_contract
      body = render_page

      expect(body).to include("You have a pending contract for this organization.")
      expect(body).to include("The contract is still pending because you (#{signee.email}) haven't signed it yet.")
      expect(body).to include("This is a fiscal sponsorship agreement between you and HCB. We need it signed before you can help manage this organization's funds.")
    end
  end

  context "when the invitee has signed and a cosigner hasn't" do
    it "says the contract is with their cosigner" do
      contract = send_contract(cosigner: true)
      contract.party(:signee).mark_signed!
      body = render_page

      expect(body).to include(signed_title)
      expect(body).to include("We're waiting for your parent / legal guardian to sign it.")
    end
  end

  context "when the invitee has signed and only HCB remains" do
    it "says HCB is reviewing it" do
      contract = send_contract
      contract.party(:signee).mark_signed!
      body = render_page

      expect(body).to include(signed_title)
      expect(body).to include("The HCB team is reviewing it. We'll email you once it's complete.")
    end
  end
end
