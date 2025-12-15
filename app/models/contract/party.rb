# frozen_string_literal: true

# == Schema Information
#
# Table name: contract_parties
#
#  id             :bigint           not null, primary key
#  aasm_state     :string
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
    include Hashid::Rails
    hashid_config salt: Credentials.fetch(:HASHID_SALT)

    acts_as_paranoid
    has_paper_trail

    belongs_to :user, optional: true
    belongs_to :contract, optional: false

    enum :role, { signee: 0, cosigner: 1, hcb: 2 }

    validates :role, uniqueness: { scope: :contract }
    validate :signee_is_user
    validate :contract_is_pending, on: :create

    validates_email_format_of :external_email, allow_nil: true, allow_blank: true
    normalizes :external_email, with: ->(external_email) { external_email.strip.downcase }

    aasm timestamps: true do
      state :pending, initial: true
      state :signed

      event :mark_signed do
        transitions from: :pending, to: :signed
        after do
          if contract.parties.all?(&:signed?)
            contract.mark_signed!
          end
        end

      end
    end

    def email
      user&.email || external_email
    end

    def notify
      Contract::PartyMailer.with(party: self).notify.deliver_later
    end

    def docuseal_signature_url
      "https://docuseal.co/s/#{contract.docuseal_document["submitters"].select { |s| s["role"] == docuseal_role }[0]["slug"]}"
    end

    def docuseal_role
      case role
      when "signee"
        "Contract Signee"
      when "cosigner"
        "Cosigner"
      when "hcb"
        "HCB"
      else
        raise "Unexpected role"
      end
    end

    private

    def signee_is_user
      if signee? && user.nil?
        errors.add(:base, "signee parties must have a user on HCB")
      end
    end

    def contract_is_pending
      unless contract.pending?
        errors.add(:contract, "cannot have parties added after it is sent")
      end
    end

  end

end
