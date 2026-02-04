# frozen_string_literal: true

# == Schema Information
#
# Table name: event_applications
#
#  id                           :bigint           not null, primary key
#  aasm_state                   :string           not null
#  accessibility_notes          :text
#  address_city                 :string
#  address_country              :string
#  address_line1                :string
#  address_line2                :string
#  address_postal_code          :string
#  address_state                :string
#  airtable_status              :string
#  annual_budget_cents          :integer
#  approved_at                  :datetime
#  committed_amount_cents       :integer
#  cosigner_email               :string
#  currently_fiscally_sponsored :boolean
#  description                  :text
#  funding_source               :string
#  last_page_viewed             :string
#  last_viewed_at               :datetime
#  name                         :string
#  planning_duration            :string
#  political_description        :text
#  project_category             :string
#  referral_code                :string
#  referrer                     :string
#  rejected_at                  :datetime
#  submitted_at                 :datetime
#  team_size                    :integer
#  teen_led                     :boolean
#  under_review_at              :datetime
#  website_url                  :string
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  airtable_record_id           :string
#  event_id                     :bigint
#  user_id                      :bigint           not null
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

    include PgSearch::Model
    pg_search_scope :search_name, against: :name

    include AASM
    include Contractable

    include PublicIdentifiable
    set_public_id_prefix :apl
    hashid_config salt: Credentials.fetch(:HASHID_SALT)

    belongs_to :user
    belongs_to :event, optional: true

    has_many :affiliations, as: :affiliable
    has_one :contract, ->{ where.not(aasm_state: :voided) }, inverse_of: :contractable

    validate :cosigner_cannot_change_after_sign

    after_save :check_cosigner_update
    after_commit :sync_to_airtable

    monetize :annual_budget_cents, allow_nil: true
    monetize :committed_amount_cents, allow_nil: true

    after_create_commit do
      Event::ApplicationReminderJob.set(wait: 1.day).perform_later(self, 1)
      Event::ApplicationReminderJob.set(wait: 2.days).perform_later(self, 2)
      Event::ApplicationReminderJob.set(wait: 7.days).perform_later(self, 3)
      Event::ApplicationReminderJob.set(wait: 14.days).perform_later(self, 4)
    end

    enum :last_page_viewed, {
      show: "show",
      project_info: "project_info",
      personal_info: "personal_info",
      review: "review",
      agreement: "agreement",
      submission: "submission"
    }

    aasm timestamps: true do
      state :draft, initial: true
      state :submitted
      # An application can be submitted but not yet under review if it is pending on signee or cosigner signatures
      # Adults (>18) will immediately advance to under_review, as they do not sign until they have been approved
      state :under_review
      state :approved
      state :rejected

      event :mark_submitted do
        transitions from: :draft, to: :submitted
        after do
          if user.teenager?
            create_contract
            Event::ApplicationMailer.with(application: self).confirmation.deliver_later
          else
            mark_under_review!
          end
        end
      end

      event :mark_under_review do
        transitions from: [:draft, :submitted], to: :under_review
        after do
          Event::ApplicationMailer.with(application: self).under_review.deliver_later
        end
      end

      event :mark_approved do
        transitions from: [:submitted, :under_review], to: :approved
        after do
          unless user.teenager?
            create_contract unless contract.present?
            Event::ApplicationMailer.with(application: self).approved.deliver_later
          end
        end
      end

      event :mark_rejected do
        transitions from: [:submitted, :under_review], to: :rejected
      end
    end

    scope :in_progress, -> { where.not(aasm_state: ["approved", "rejected"]) }

    def rejection_messages
      generic = <<~MSG.strip
        Hi #{user.first_name},

        Thank you for expressing interest in using HCB for your project, #{name}. After careful consideration, we're unable to move forward with your application at this time.

        If you have any questions, feel free to reach out to us at [hcb@hackclub.com](mailto:hcb@hackclub.com) or reply to this email.

        Best,
        The HCB Team
      MSG

      adult = <<~MSG.strip
        Hi #{user.first_name},

        Thank you for expressing interest in using HCB for your project, #{name}. After careful consideration, we're unable to move forward with your application at this time. HCB is primarily focused on supporting projects run by teenagers.

        If you have any questions, feel free to reach out to us at [hcb@hackclub.com](mailto:hcb@hackclub.com) or reply to this email.

        Best,
        The HCB Team
      MSG

      mission = <<~MSG.strip
        Hi #{user.first_name},

        Thank you for expressing interest in using HCB for your project, #{name}. After careful consideration, we're unable to move forward with your application at this time. Your project's mission doesn't align with HCB's guidelines, and as a result, we cannot approve your application.

        If you have any questions, feel free to reach out to us at [hcb@hackclub.com](mailto:hcb@hackclub.com) or reply to this email.

        Best,
        The HCB Team
      MSG

      {
        generic:,
        adult:,
        mission:
      }
    end

    def next_step
      return "Tell us about your project" if name.blank? || description.blank?
      return "Add your information" if address_line1.blank? || address_city.blank? || address_country.blank? || address_postal_code.blank?
      return "Review and submit" if draft?
      return "Sign the fiscal sponsorship agreement" if submitted?
      return "Start spending!" if approved?
      return "" if rejected?
    end

    def completion_percentage
      return 25 if next_step == "Tell us about your project"
      return 50 if next_step == "Add your information"
      return 75 if next_step == "Review and submit"
      return 100 if submitted? || under_review?

      0
    end

    def political?
      political_description.present? && political_description.strip.length.positive?
    end

    def contract_notify_when_sent
      false
    end

    def contract_redirect_path
      Rails.application.routes.url_helpers.application_path(self)
    end

    def create_contract
      if name.nil? || description.nil?
        raise StandardError.new("Cannot create a contract for application #{hashid}: missing name and/or description")
      end

      fs_contract = nil
      ActiveRecord::Base.transaction do
        fs_contract = Contract::FiscalSponsorship.create!(contractable: self, include_videos: false, external_template_id: Event::Plan::Standard.new.contract_docuseal_template_id, prefills: { "public_id" => public_id, "name" => name, "description" => description })
        fs_contract.parties.create!(user:, role: :signee)
        fs_contract.parties.create!(external_email: cosigner_email, role: :cosigner) if cosigner_email.present?
      end

      fs_contract.send!
      fs_contract.party(:cosigner)&.notify

      fs_contract
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

    def status_color
      return :muted if draft? || submitted?
      return :blue if under_review?
      return :green if approved?
      return :red if rejected?

      :muted
    end

    def on_contract_party_signed(party)
      if party.contract.parties.not_hcb.all?(&:signed?) && party.contract.party(:hcb).pending? && submitted?
        mark_under_review!
      end
    end

    def sync_to_airtable
      return if draft?

      app = ApplicationsTable.all(filter: "{recordID} = \"#{airtable_record_id}\"").first if airtable_record_id.present?
      app ||= ApplicationsTable.all(filter: "{HCB Application ID} = \"#{hashid}\"").first
      app ||= ApplicationsTable.new("HCB Application ID" => hashid)

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
      app["HCB Status"] = aasm_state.humanize unless draft?
      app["Synced from HCB at"] = Time.current

      app.save

      update_columns(airtable_record_id: app.id, airtable_status: app["Status"])
    end

    def airtable_url
      return nil unless airtable_record_id.present?

      "https://airtable.com/#{ApplicationsTable.base_key}/#{ApplicationsTable.table_name}/#{airtable_record_id}"
    end

    def record_pageview(last_page_viewed)
      update!(last_viewed_at: Time.current, last_page_viewed:)
    end

    def check_cosigner_update
      if contract.present? && cosigner_email_previously_changed?
        contract.mark_voided!
        create_contract
      end
    end

    def activate_event!
      raise "Contract must be signed before activation" unless contract.signed?

      poc = contract.party(:hcb).user

      Event.create!(
        name:,
        country: address_country,
        point_of_contact_id: poc.id,
        application: self
      )

      service = OrganizerPositionInviteService::Create.new(event:, sender: poc, user_email: user.email, is_signee: true, role: :manager, initial: true)
      invite = service.model
      service.run!

      invite.accept(application_contract: contract)

      affiliations.each do |affiliation|
        affiliation_copy = affiliation.dup
        affiliation_copy.affiliable = event
        affiliation_copy.save!
      end

      Event::ApplicationMailer.with(application: self).activated.deliver_later

      self
    end

    private

    def cosigner_cannot_change_after_sign
      if cosigner_email_changed? && contract&.party(:cosigner)&.signed?
        errors.add(:cosigner_email, "cannot change after the cosigner has signed")
      end
    end

  end

end
