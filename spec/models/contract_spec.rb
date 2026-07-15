# frozen_string_literal: true

require "rails_helper"

RSpec.describe Contract, type: :model do
  describe "#mark_voided! archival behavior" do
    let(:payee) { create(:payee) }
    let(:position) { create(:payroll_position, payee:) }

    before do
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
    end

    it "does not contact DocuSeal for a contract that was never sent" do
      contract = Contract::PayrollPosition.create!(contractable: position, include_videos: false)

      expect { contract.mark_voided!(reissuing: true) }.not_to raise_error
      expect(contract).to be_voided
    end

  end
end
