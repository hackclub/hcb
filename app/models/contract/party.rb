# frozen_string_literal: true

# == Schema Information
#
# Table name: contract_parties
#
#  id             :bigint           not null, primary key
#  aasm_state     :string           not null
#  deleted_at     :datetime
#  external_email :string
#  role           :string           not null
#  signed_at      :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  contract_id    :bigint           not null
#  external_id    :string
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

    acts_as_paranoid
    has_paper_trail

    belongs_to :user, optional: true
    belongs_to :contract, optional: false

    enum :role, { signee: "signee", cosigner: "cosigner", hcb: "hcb", organizer: "organizer", contractor: "contractor" }

    attr_accessor :skip_pending_validation

    validates :role, uniqueness: { scope: :contract }
    validate :role_permitted_for_contract_type
    validate :signee_is_user
    validate :contract_is_pending, on: :create, unless: :skip_pending_validation
    validate :email_cannot_change_after_sign

    validates_email_format_of :external_email, allow_nil: true, allow_blank: true
    normalizes :external_email, with: ->(external_email) { external_email.strip.downcase }

    aasm timestamps: true do
      state :pending, initial: true
      state :signed

      event :mark_signed do
        transitions from: :pending, to: :signed
        after do
          contract.on_party_signed(self)
        end

      end
    end

    def email
      user&.email || external_email
    end

    def notify
      contract.contractable.notify_mailer_for(self)
    end

    def notify_reissued(message: nil)
      Contract::PartyMailer.with(party: self, message:).reissued.deliver_later
    end

    def docuseal_signature_url
      "https://docuseal.co/s/#{external_id}"
    end

    def docuseal_role
      case role
      when "signee"
        "Contract Signee"
      when "cosigner"
        "Cosigner"
      when "hcb"
        "HCB"
      when "organizer"
        "Organizer"
      when "contractor"
        "Contractor"
      else
        raise "Unexpected role"
      end
    end

    def notify_email_subject
      if hcb?
        "Sign #{contract.event_name}'s agreement as HCB Operations"
      elsif cosigner?
        "#{contract.party(:signee).user.name} invited you to sign a fiscal sponsorship agreement for #{contract.event_name} on HCB 📝"
      else
        "You've been invited to sign an agreement for #{contract.event_name} on HCB 📝"
      end
    end

    def reissue_email_subject
      "There was an issue in the agreement you signed for #{contract.event_name} on HCB 📝"
    end

    def reminder_email_subject
      "[Action Needed] Sign the #{contract.agreement_name} for #{contract.event_name} on HCB 📝"
    end

    # We may miss a webhook or load a page before we've received the webhook,
    # so we can manually sync the party with this method!
    def sync_with_docuseal
      self.with_lock do
        if pending? && docuseal_submission&.[]("status") == "completed"
          mark_signed!
        end
      end
    end

    def schedule_reminders
      Contract::Party::ReminderJob.set(wait: 3.days).perform_later(self)
      Contract::Party::ReminderJob.set(wait: 7.days).perform_later(self)
      Contract::Party::ReminderJob.set(wait: 14.days).perform_later(self)
      Contract::Party::ReminderJob.set(wait: 30.days).perform_later(self)
      Contract::Party::ReminderJob.set(wait: 45.days).perform_later(self)
      Contract::Party::ReminderJob.set(wait: 60.days).perform_later(self)
    end

    private

    def docuseal_submission
      contract.docuseal_document["submitters"].select { |s| s["role"] == docuseal_role }[0]
    end

    def role_permitted_for_contract_type
      return if contract.nil? || role.nil?

      unless contract.permitted_roles.include?(role)
        errors.add(:role, "#{role} is not a valid party for a #{contract.model_name.human.downcase}")
      end
    end

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

    def email_cannot_change_after_sign
      if self["aasm_state"] == "signed" && (user_changed? || external_email_changed?)
        errors.add(:base, "The signing party cannot change after it has signed the contract")
      end
    end

  end

end
