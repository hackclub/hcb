# frozen_string_literal: true

require "rails_helper"

RSpec.describe Contract::FiscalSponsorship, type: :model do
  describe "#agreement_name" do
    # Unsaved contracts are enough here: the name is derived entirely from the
    # DocuSeal template the contract was issued against.
    def agreement_name_for(external_template_id)
      described_class.new(external_template_id:).agreement_name
    end

    it "calls Hack Club HQ's own template a contract" do
      template = Event::Plan::HackClubAffiliate.new.contract_docuseal_template_id

      expect(agreement_name_for(template)).to eq "contract"
    end

    it "calls every other template a fiscal sponsorship agreement" do
      template = Event::Plan::Standard.new.contract_docuseal_template_id

      expect(agreement_name_for(template)).to eq "fiscal sponsorship agreement"
    end

    it "calls a contract with no recorded template a fiscal sponsorship agreement" do
      expect(agreement_name_for(nil)).to eq "fiscal sponsorship agreement"
    end
  end

  describe "#standard_fiscal_sponsorship?" do
    def standard_for(external_template_id)
      described_class.new(external_template_id:).standard_fiscal_sponsorship?
    end

    it "is true for the standard plan's template" do
      expect(standard_for(Event::Plan::Standard.new.contract_docuseal_template_id)).to be true
    end

    it "is true for a plan that inherits the standard template" do
      template = Event::Plan::FeeWaived.new.contract_docuseal_template_id

      expect(template).to eq Event::Plan::Standard.new.contract_docuseal_template_id
      expect(standard_for(template)).to be true
    end

    it "is false for a plan with its own agreement" do
      expect(standard_for(Event::Plan::HackClubAffiliate.new.contract_docuseal_template_id)).to be false
    end

    it "is false for a contract with no recorded template" do
      expect(standard_for(nil)).to be false
    end
  end
end
