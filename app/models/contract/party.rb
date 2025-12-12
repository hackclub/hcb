# frozen_string_literal: true

# == Schema Information
#
# Table name: contract_parties
#
#  id             :bigint           not null, primary key
#  external_email :string
#  role           :integer          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  contract_id    :bigint           not null
#  user_id        :bigint
#
# Indexes
#
#  index_contract_parties_on_contract_id  (contract_id)
#  index_contract_parties_on_user_id      (user_id)
#
class Contract
  class Party < ApplicationRecord
    include AASM

    belongs_to :user, optional: true
    belongs_to :contract

    enum :role, { signee: 0, cosigner: 1 }

    validates :role, uniqueness: { scope: :contract }
    validate :contract_is_pending, on: :create

    aasm timestamps: true do
      state :pending, initial: true
      state :signed

      event :mark_signed do
        transitions from: :pending, to: :signed
        after do
          if contract.parties.all?(&:signed?)
            contract.mark_signeed!
          end
        end

      end
    end

    private

    def contract_is_pending
      unless contract.pending?
        errors.add(:contract, "cannot have parties added after it is sent")
      end
    end

  end

end
