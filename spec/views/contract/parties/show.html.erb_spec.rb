# frozen_string_literal: true

require "rails_helper"

RSpec.describe "contract/parties/show" do
  let(:event) { create(:event) }
  let(:signee) { create(:user) }
  let(:invite) { create(:organizer_position_invite, event:, user: signee) }

  let(:standard_template) { Event::Plan::Standard.new.contract_docuseal_template_id }
  let(:other_template) { Event::Plan::HackClubAffiliate.new.contract_docuseal_template_id }

  let(:faq_title) { "Questions about the HCB agreement?" }
  let(:videos_title) { "Watch the onboarding videos" }

  before do
    allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
  end

  # The same shape OrganizerPositionInvite#send_contract builds, minus DocuSeal.
  def contract_with(template:, cosigner: false)
    contract = Contract::FiscalSponsorship.create!(contractable: invite, include_videos: false, external_template_id: template)
    contract.parties.create!(user: signee, role: :signee)
    contract.parties.create!(role: :cosigner, external_email: "parent@example.com") if cosigner
    contract
  end

  def render_page(party)
    assign(:party, party)
    assign(:contract, party.contract)
    render template: "contract/parties/show"
  end

  context "when signing the standard fiscal sponsorship agreement" do
    it "shows the FAQ in a sidebar next to the contract" do
      contract = contract_with(template: standard_template)
      render_page(contract.party(:signee))

      expect(rendered).to include(faq_title)
      expect(rendered).to include(videos_title)
      expect(rendered).to include("md:col-span-3")
    end

    it "shows the FAQ to the cosigner too" do
      contract = contract_with(template: standard_template, cosigner: true)
      render_page(contract.party(:cosigner))

      expect(rendered).to include(faq_title)
      expect(rendered).not_to include(videos_title)
      expect(rendered).to include("md:col-span-3")
    end
  end

  context "when signing an agreement issued from another template" do
    it "keeps the onboarding videos in the sidebar but drops the FAQ" do
      contract = contract_with(template: other_template)
      render_page(contract.party(:signee))

      expect(rendered).not_to include(faq_title)
      expect(rendered).to include(videos_title)
      expect(rendered).to include("md:col-span-3")
    end

    it "gives the contract the full width once nothing is left for the sidebar" do
      contract = contract_with(template: other_template, cosigner: true)
      render_page(contract.party(:cosigner))

      expect(rendered).not_to include(faq_title)
      expect(rendered).not_to include(videos_title)
      expect(rendered).to include("md:col-span-5")
      expect(rendered).not_to include("md:col-span-2")
    end
  end
end
