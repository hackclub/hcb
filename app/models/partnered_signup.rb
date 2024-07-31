# frozen_string_literal: true

# == Schema Information
#
# Table name: partnered_signups
#
#  id                        :bigint           not null, primary key
#  aasm_state                :string
#  accepted_at               :datetime
#  applicant_signed_at       :datetime
#  completed_at              :datetime
#  country                   :integer
#  legal_acknowledgement     :boolean
#  organization_name         :string           not null
#  owner_address             :string
#  owner_address_city        :string
#  owner_address_country     :integer
#  owner_address_line1       :string
#  owner_address_line2       :string
#  owner_address_postal_code :text
#  owner_address_state       :string
#  owner_birthdate           :date
#  owner_email               :string
#  owner_name                :string
#  owner_phone               :string
#  redirect_url              :string           not null
#  rejected_at               :datetime
#  submitted_at              :datetime
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  event_id                  :bigint
#  partner_id                :bigint           not null
#  user_id                   :bigint
#
# Indexes
#
#  index_partnered_signups_on_event_id    (event_id)
#  index_partnered_signups_on_partner_id  (partner_id)
#  index_partnered_signups_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (partner_id => partners.id)
#  fk_rails_...  (user_id => users.id)
#
class PartneredSignup < ApplicationRecord
  self.ignored_columns = ["docusign_template_id"]

  has_paper_trail

  include PublicIdentifiable
  set_public_id_prefix :sup

  include CountryEnumable
  has_country_enum

  belongs_to :partner
  belongs_to :event, optional: true
  belongs_to :user,  optional: true

  validates :redirect_url, presence: true
  validates_presence_of [:organization_name,
                         :owner_name,
                         :owner_email,
                         :owner_phone,
                         :owner_address_line1,
                         # :owner_address_line2,
                         # ^ intentionally blank, as this is optional
                         :owner_address_city,
                         :owner_address_state,
                         :owner_address_postal_code,
                         :owner_address_country,
                         :owner_birthdate], unless: :unsubmitted?

  include AASM

  aasm timestamps: true do
    state :unsubmitted, initial: true # Partner reaches out to create a signup
    state :submitted # Owner filled out details on form
    state :applicant_signed # Owner signed contract

    state :rejected # Admin turned down contract

    state :accepted # Admin signed contract
    state :completed # Signed contract has been downloaded as PDF, org has been created, users have been invited

    # The ending state of a SUP should be either `rejected` or `completed`

    event :mark_submitted do
      # Sync this Partnered Signup to Airtable when it is submitted
      after do
        puts self.id
        ::PartneredSignupJob::SyncToAirtable.perform_later(partnered_signup_id: self.id)
      end

      transitions from: :unsubmitted, to: :submitted
    end

    event :mark_applicant_signed do
      transitions from: :submitted, to: :applicant_signed

      after do
        signed_contract = true;
      end
    end

    event :mark_rejected do
      transitions from: [:submitted, :applicant_signed], to: :rejected
    end

    event :mark_accepted do
      transitions from: :applicant_signed, to: :accepted
    end

    event :mark_completed do
      transitions from: :accepted, to: :completed
    end
  end

  scope :not_unsubmitted, -> { where.not(aasm_state: :unsubmitted) }

  def continue_url
    Rails.application.routes.url_helpers.edit_partnered_signups_url(public_id:)
  end

  def state_text
    aasm.human_state
  end

  def api_status
    return "rejected" if rejected?
    return "approved" if completed?

    # Applicant needs to sign for the contract for the SUP to be considered
    # fully submitted from the Partner's perspective.
    return "unsubmitted" if unsubmitted? || submitted?
    return "submitted" if applicant_signed?

    ""
  end

end
