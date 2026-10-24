# frozen_string_literal: true

require "rails_helper"

RSpec.describe "contract/parties/_fs_contract_faq" do
  let(:faq_title) { "Questions about the HCB agreement?" }
  let(:standard_template) { Event::Plan::Standard.new.contract_docuseal_template_id }

  # Unsaved contracts are enough: the partial only looks at the contract's
  # type and the template it was issued from.
  def render_faq(contract, **locals)
    render partial: "contract/parties/fs_contract_faq", locals: { contract:, **locals }
    rendered
  end

  it "renders for the standard fiscal sponsorship agreement" do
    contract = Contract::FiscalSponsorship.new(external_template_id: standard_template)

    expect(render_faq(contract)).to include(faq_title)
  end

  it "renders nothing for a fiscal sponsorship agreement issued from another template" do
    contract = Contract::FiscalSponsorship.new(external_template_id: Event::Plan::HackClubAffiliate.new.contract_docuseal_template_id)

    expect(render_faq(contract)).to be_blank
  end

  it "renders nothing for other kinds of contract" do
    expect(render_faq(Contract::PayrollPosition.new)).to be_blank
  end

  it "adds the given classes to the callout" do
    contract = Contract::FiscalSponsorship.new(external_template_id: standard_template)

    expect(render_faq(contract, klass: "h-[40vh]")).to include("h-[40vh]")
  end
end
