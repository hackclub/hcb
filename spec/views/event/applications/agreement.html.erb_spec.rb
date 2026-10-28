# frozen_string_literal: true

require "rails_helper"

RSpec.describe "event/applications/agreement" do
  let(:application) { create(:event_application) }
  let(:faq_title) { "Questions about the HCB agreement?" }

  before do
    allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
  end

  # Applications only ever issue the standard agreement today
  # (Event::Application#send_contract); this pins down what the page does
  # should that change.
  def contract_with(template:)
    contract = Contract::FiscalSponsorship.create!(contractable: application, include_videos: false, external_template_id: template)
    contract.parties.create!(user: application.user, role: :signee)
    application.reload
    contract
  end

  def render_info_pane(contract)
    assign(:application, application)
    assign(:contract, contract)
    assign(:party, contract.party(:signee))
    render template: "event/applications/agreement"
    view.content_for(:info_pane)
  end

  it "explains the standard agreement in the info pane" do
    contract = contract_with(template: Event::Plan::Standard.new.contract_docuseal_template_id)

    expect(render_info_pane(contract)).to include(faq_title)
  end

  it "leaves the FAQ, and the box that held it, out for any other agreement" do
    contract = contract_with(template: Event::Plan::HackClubAffiliate.new.contract_docuseal_template_id)
    info_pane = render_info_pane(contract)

    expect(info_pane).to include("Sign the HCB agreement")
    expect(info_pane).not_to include(faq_title)
    expect(info_pane).not_to include("h-[40vh]")
  end
end
