# frozen_string_literal: true

require "rails_helper"

RSpec.describe Contract::Party, type: :model do
  describe "role scoping to contract type" do
    # Unsaved contracts are enough here: the validation only reads
    # #permitted_roles and #model_name, so we avoid the contractable +
    # after_create HCB-party machinery.
    let(:fiscal_sponsorship) { Contract::FiscalSponsorship.new }
    let(:payroll_position) { Contract::PayrollPosition.new }

    def role_errors(contract:, role:)
      party = described_class.new(contract:, role:)
      party.valid?
      party.errors[:role]
    end

    context "fiscal sponsorship contract" do
      it "permits its own roles" do
        %w[hcb signee cosigner].each do |role|
          expect(role_errors(contract: fiscal_sponsorship, role:)).to be_empty
        end
      end

      it "rejects payroll roles" do
        %w[organizer contractor].each do |role|
          expect(role_errors(contract: fiscal_sponsorship, role:))
            .to include(a_string_including("not a valid party for a fiscal sponsorship"))
        end
      end
    end

    context "payroll position contract" do
      it "permits its own roles" do
        %w[hcb organizer contractor].each do |role|
          expect(role_errors(contract: payroll_position, role:)).to be_empty
        end
      end

      it "rejects fiscal sponsorship roles" do
        %w[signee cosigner].each do |role|
          expect(role_errors(contract: payroll_position, role:))
            .to include(a_string_including("not a valid party for a payroll position"))
        end
      end
    end
  end

  describe "#permitted_roles is a superset of #required_roles" do
    [Contract::FiscalSponsorship, Contract::PayrollPosition].each do |klass|
      it "holds for #{klass}" do
        contract = klass.new
        expect(contract.required_roles).to all(be_in(contract.permitted_roles))
      end
    end
  end
end
