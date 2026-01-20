# frozen_string_literal: true

# == Schema Information
#
# Table name: event_applications
#
#  id                    :bigint           not null, primary key
#  aasm_state            :string
#  address_city          :string
#  address_country       :string
#  address_line1         :string
#  address_line2         :string
#  address_postal_code   :string
#  address_state         :string
#  airtable_status       :string
#  approved_at           :datetime
#  cosigner_email        :string
#  description           :text
#  name                  :string
#  notes                 :text
#  political_description :text
#  referral_code         :string
#  referrer              :string
#  rejected_at           :datetime
#  submitted_at          :datetime
#  under_review_at       :datetime
#  website_url           :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  airtable_record_id    :string
#  event_id              :bigint
#  user_id               :bigint           not null
#
# Indexes
#
#  index_event_applications_on_event_id  (event_id)
#  index_event_applications_on_user_id   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (user_id => users.id)
#
class Event
  class Application < ApplicationRecord
    include AASM
    include Contractable

    include PublicIdentifiable
    set_public_id_prefix :app

    belongs_to :user
    belongs_to :event, optional: true

    aasm timestamps: true do
      state :draft, initial: true
      state :submitted
      # An application can be submitted but not yet under review if it is pending on signee or cosigner signatures
      state :under_review
      state :approved
      state :rejected

      event :mark_submitted do
        transitions from: :draft, to: :submitted
        after do
          app_contract = contract || create_contract
          app_contract.party(:cosigner)&.notify
          Event::ApplicationMailer.with(application: self).confirmation.deliver_later
        end
      end

      event :mark_under_review do
        transitions from: :submitted, to: :under_review
        after do
          Event::ApplicationMailer.with(application: self).under_review.deliver_later
        end
      end
    end

    def next_step
      return "Tell us about your project" if name.blank? || description.blank?
      return "Add your information" if address_line1.blank? || address_city.blank? || address_country.blank? || address_postal_code.blank?
      return "Review and submit" if draft?
    end

    def status_color
      return :muted if draft?
      return :blue if submitted?
      return :purple if under_review?
      return :green if approved?
      return :red if rejected?

      :muted
    end

    def completion_percentage
      return 25 if next_step == "Tell us about your project"
      return 50 if next_step == "Add your information"
      return 75 if next_step == "Review and submit"
      return 100 if submitted?

      0
    end

    def political?
      political_description.present? && political_description.strip.length.positive?
    end

    def contract
      contracts.where.not(aasm_state: :voided).last
    end

    def contract_notify_when_sent
      false
    end

    def contract_redirect_path
      Rails.application.routes.url_helpers.application_path(self)
    end

    def create_contract
      if name.nil? || description.nil?
        raise StandardError.new("Cannot create a contract for application #{id}: missing name and/or description")
      end

      ActiveRecord::Base.transaction do
        contract = Contract::FiscalSponsorship.create!(contractable: self, include_videos: false, external_template_id: Event::Plan::Standard.new.contract_docuseal_template_id, prefills: { "public_id" => public_id, "name" => name, "description" => description })
        contract.parties.create!(user:, role: :signee)
        contract.parties.create!(external_email: cosigner_email, role: :cosigner) if cosigner_email.present?
      end

      contract.send!

      contract
    end

    def ready_to_submit?
      required_fields = ["name", "description", "address_line1", "address_city", "address_state", "address_postal_code", "address_country", "referrer"]

      if user.age < 18
        required_fields.push("cosigner_email")
      end

      missing_fields = required_fields.any? do |field|
        self[field].nil?
      end

      !missing_fields && !user.onboarding?
    end

    def on_contract_party_signed(party)
      if party.contract.parties.not_hcb.all?(&:signed?)
        mark_under_review!
      end
    end

  end

end
