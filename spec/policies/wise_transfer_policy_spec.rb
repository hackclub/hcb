# frozen_string_literal: true

require "rails_helper"

RSpec.describe WiseTransferPolicy, type: :policy do
  let(:admin) { create(:user, :make_admin) }
  let(:non_admin) { create(:user) }

  def wise_transfer_in(aasm_state)
    WiseTransfer.new(aasm_state:)
  end

  [:edit?, :update?].each do |permission|
    describe "##{permission}" do
      ["pending", "approved"].each do |aasm_state|
        it "allows admins when the transfer is #{aasm_state}" do
          expect(described_class.new(admin, wise_transfer_in(aasm_state)).public_send(permission)).to eq(true)
        end

        it "does not allow non-admins when the transfer is #{aasm_state}" do
          expect(described_class.new(non_admin, wise_transfer_in(aasm_state)).public_send(permission)).to eq(false)
        end
      end

      ["sent", "deposited", "rejected", "failed"].each do |aasm_state|
        it "does not allow admins when the transfer is #{aasm_state}" do
          expect(described_class.new(admin, wise_transfer_in(aasm_state)).public_send(permission)).to eq(false)
        end
      end
    end
  end
end
