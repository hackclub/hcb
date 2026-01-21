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
#  last_page_viewed      :integer
#  last_viewed_at        :datetime
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
    has_paper_trail

    include AASM
    include Contractable

    include PublicIdentifiable
    set_public_id_prefix :app

    belongs_to :user
    belongs_to :event, optional: true

    enum :last_page_viewed, {
      show: 0,
      project_info: 1,
      personal_info: 2,
      review: 3,
      agreement: 4,
      submission: 5
    }

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
          sync_to_airtable
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

    def response_time
      user.teenager? ? "48 hours" : "2 weeks"
    end

    def on_contract_party_signed(party)
      if party.contract.parties.not_hcb.all?(&:signed?)
        mark_under_review!
      end
    end

    def sync_to_airtable
      app = ApplicationsTable.new("HCB Application ID" => self.id)
      app["First Name"] = user.first_name
      app["Last Name"] = user.last_name
      app["Email Address"] = user.email
      app["Phone Number"] = user.phone_number
      app["Date of Birth"] = user.birthday
      app["Event Name"] = name
      app["Event Website"] = website_url
      app["Zip Code"] = address_postal_code
      app["Tell us about your event"] = description
      app["Have you used HCB for any previous events?"] = user.events.any? ? "Yes, I have used HCB before" : "No, first time!"
      app["Teenager Led?"] = user.teenager?
      app["Address Line 1"] = address_line1
      app["City"] = address_city
      app["State"] = address_state
      app["Address Country"] = address_country
      app["Event Location"] = address_country
      app["How did you hear about HCB?"] = referrer
      app["Accommodations"] = notes
      app["(Adults) Political Activity"] = political_description
      app["Referral Code"] = referral_code

      app.save
    end

    def record_pageview(last_page_viewed)
      update!(last_viewed_at: Time.current, last_page_viewed:)
    end

  end

end
