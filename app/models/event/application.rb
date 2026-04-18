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
#  airtable_synced_at           :datetime
#  annual_budget_cents          :integer
#  approved_at                  :datetime
#  archived_at                  :datetime
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
#  previously_applied           :boolean
#  project_category             :string
#  referral_code                :string
#  referrer                     :string
#  rejected_at                  :datetime
#  submitted_at                 :datetime
#  team_size                    :integer
#  teen_led                     :boolean
#  under_review_at              :datetime
#  videos_watched               :boolean          default(FALSE)
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

    include Hashid::Rails

    include PublicIdentifiable
    set_public_id_prefix :apl

    belongs_to :user
    belongs_to :event, optional: true
    belongs_to :contract_event, foreign_key: :event_id, class_name: "Event", inverse_of: :application, optional: true

    has_many :affiliations, as: :affiliable
    has_one :contract, ->{ where.not(aasm_state: :voided) }, inverse_of: :contractable, as: :contractable

    validate :cosigner_cannot_change_after_sign

    after_save :check_cosigner_update
    after_commit :schedule_airtable_sync, unless: :saved_change_to_airtable_synced_at?

    monetize :annual_budget_cents, allow_nil: true
    monetize :committed_amount_cents, allow_nil: true

    include Rails.application.routes.url_helpers

    after_create_commit do
      Event::ApplicationReminderJob.set(wait: 1.day).perform_later(self, 1)
      Event::ApplicationReminderJob.set(wait: 2.days).perform_later(self, 2)
      Event::ApplicationReminderJob.set(wait: 7.days).perform_later(self, 3)
      Event::ApplicationReminderJob.set(wait: 14.days).perform_later(self, 4)
    end

    scope :not_archived, -> { where(archived_at: nil) }
    scope :archived, -> { where.not(archived_at: nil) }

    scope :active, -> { where(archived_at: nil, event_id: nil) }

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
        transitions from: :draft, to: :submitted, if: :ready_to_submit?

        after do
          update!(archived_at: nil)

          if teen_led?
            send_contract
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
        transitions from: :under_review, to: :approved
        after do
          if teen_led?
            contract.party(:hcb).schedule_reminders
          else
            send_contract unless contract.present?
            Event::ApplicationMailer.with(application: self).approved.deliver_later
          end
        end
      end

      event :mark_rejected do
        transitions from: [:submitted, :under_review], to: :rejected
        after do |rejection_message|
          contract.mark_voided! if contract.present?

          if rejection_message.present?
            Event::ApplicationMailer.with(application: self, rejection_message: rejection_message).rejected.deliver_later
          end
        end
      end
    end

    scope :in_progress, -> { where.not(aasm_state: ["approved", "rejected"]) }

    DISALLOWED_COUNTRIES = %w[IN NG RU CU IR KP SY BY VE SD SS MM AF YE SO PK CF CG ZW LY CM LB IQ].freeze

    def rejection_messages
      generic = <<~MSG.strip
        Hi #{user.first_name},

        Thank you for expressing interest in using HCB for your project, [#{name}](#{Rails.application.routes.url_helpers.application_url(self)}). After careful consideration, we're unable to move forward with your application at this time.

        If you have any questions, feel free to reach out to us at [hcb@hackclub.com](mailto:hcb@hackclub.com) or reply to this email.

        Best,
        The HCB Team
      MSG

      adult = <<~MSG.strip
        Hi #{user.first_name},

        Thank you for expressing interest in using HCB for your project, [#{name}](#{Rails.application.routes.url_helpers.application_url(self)}). After careful consideration, we're unable to move forward with your application at this time. HCB is primarily focused on supporting projects run by teenagers.

        If you have any questions, feel free to reach out to us at [hcb@hackclub.com](mailto:hcb@hackclub.com) or reply to this email.

        Best,
        The HCB Team
      MSG

      mission = <<~MSG.strip
        Hi #{user.first_name},

        Thank you for expressing interest in using HCB for your project, [#{name}](#{Rails.application.routes.url_helpers.application_url(self)}). After careful consideration, we're unable to move forward with your application at this time. Your project's mission doesn't align with HCB's guidelines, and as a result, we cannot approve your application.

        If you have any questions, feel free to reach out to us at [hcb@hackclub.com](mailto:hcb@hackclub.com) or reply to this email.

        Best,
        The HCB Team
      MSG

      country = <<~MSG.strip
        Hi #{user.first_name},

        Thank you for expressing interest in using HCB for your project, [#{name}](#{Rails.application.routes.url_helpers.application_url(self)}). We really want to support projects from all around the world. However, due to regulatory restrictions and incompatible financial systems, we are unable to partner with organizations that operate in certain countries.

        We're sorry for not being able to support you on your journey and wish you all the best. If you have any questions, feel free to reach out to us at [hcb@hackclub.com](mailto:hcb@hackclub.com) or reply to this email.

        Best,
        The HCB team
      MSG

      {
        generic:,
        adult:,
        mission:,
        country:
      }
    end

    def next_step
      return "Tell us about your project" if name.blank? || description.blank?
      return "Add your information" if address_line1.blank? || address_city.blank? || address_country.blank? || address_postal_code.blank?
      return "Review and submit" if draft?
      return "Sign the fiscal sponsorship agreement" if (submitted? && teen_led?) || (approved? && !teen_led?)
      return "Start spending!" if event.present?
      return "" if rejected?
    end

    def completion_percentage
      return 25 if next_step == "Tell us about your project"
      return 50 if next_step == "Add your information"
      return 75 if next_step == "Review and submit"
      return 100 if submitted? || under_review? || approved?

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

    def contract_notify_hcb?
      !teen_led?
    end

    def send_contract(reissue_signee_message: nil, reissue_cosigner_message: nil, **options)
      if name.nil? || description.nil?
        raise StandardError.new("Cannot create a contract for application #{hashid}: missing name and/or description")
      end

      if cosigner_email.present? && !user.is_minor?
        update!(cosigner_email: nil)
      end

      fs_contract = nil
      ActiveRecord::Base.transaction do
        fs_contract = Contract::FiscalSponsorship.create!(contractable: self, include_videos: false, external_template_id: Event::Plan::Standard.new.contract_docuseal_template_id, prefills: { "public_id" => public_id, "name" => name, "description" => description })
        fs_contract.parties.create!(user:, role: :signee)
        fs_contract.parties.create!(external_email: cosigner_email, role: :cosigner) if cosigner_email.present?
      end

      fs_contract.send!(reissue_signee_message:, reissue_cosigner_message:)
      fs_contract.party(:cosigner)&.notify unless reissue_signee_message.present? || reissue_cosigner_message.present?

      fs_contract
    end

    def response_time
      teen_led? ? "2 business days" : "2 weeks"
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

    def check_cosigner_update
      if contract.present? && cosigner_email_previously_changed?
        contract.mark_voided!
        send_contract
      end
    end

    def airtable_url
      return nil unless airtable_record_id.present?

      "https://airtable.com/#{ApplicationsTable.base_key}/#{ApplicationsTable.table_name}/#{airtable_record_id}"
    end

    def record_pageview(last_page_viewed)
      update!(last_viewed_at: Time.current, last_page_viewed:)
    end

    def activate_event!(risk_level:, tags: [], point_of_contact: nil)
      contract.party(:hcb).sync_with_docuseal
      contract.reload
      raise "Contract must be signed before activation" unless contract.signed?

      self.with_lock do
        raise ArgumentError.new("Event was already created") if event.present?

        poc_user = point_of_contact.presence || contract.party(:hcb).user
        Event.create!(
          name:,
          country: address_country,
          point_of_contact_id: poc_user.id,
          application: self,
          event_tags: tags.filter { |tag| EventTag::Tags::ALL.include?(tag) }.map { |tag| EventTag.find_or_create_by!(name: tag) },
          risk_level:
        )
        contract.create_document!

        service = OrganizerPositionInviteService::Create.new(event:, sender: poc_user, user_email: user.email, is_signee: true, role: :manager, initial: true)
        invite = service.model
        service.run!

        invite.accept(application_contract: contract)

        affiliations.each do |affiliation|
          affiliation_copy = affiliation.dup
          affiliation_copy.affiliable = event
          affiliation_copy.save!
        end
      end

      schedule_airtable_sync

      Event::ApplicationMailer.with(application: self).activated.deliver_later

      self
    end

    def archive!
      contract&.mark_voided! if contract&.may_mark_voided?

      update!(archived_at: Time.current)
    end

    def unarchive!
      send_contract if contract.nil? && ((teen_led && !draft? && !rejected?) || (!teen_led && approved?))

      update!(archived_at: nil)
    end

    def archived?
      archived_at.present?
    end

    def respondent_url
      url_for(controller: "event/applications", action: last_page_viewed || "show", id: hashid)
    end

    def default_tags
      tags = []

      tags << EventTag::Tags::ORGANIZED_BY_TEENAGERS if teen_led?
      tags << EventTag::Tags::ROBOTICS_TEAM if affiliations.any? { |affiliation| affiliation.is_first? || affiliation.is_vex? }
      tags << EventTag::Tags::HACK_CLUB if affiliations.any? { |affiliation| affiliation.is_hack_club? }

      tags
    end

    def airtable_record
      app = ApplicationsTable.all(filter: "{recordID} = \"#{airtable_record_id}\"").first if airtable_record_id.present?
      app ||= ApplicationsTable.all(filter: "{HCB Application ID} = \"#{hashid}\"").first
    end

    private

    def schedule_airtable_sync
      Event::ApplicationSyncToAirtableJob.perform_later(self)
    end

    def cosigner_cannot_change_after_sign
      if cosigner_email_changed? && contract&.party(:cosigner)&.signed?
        errors.add(:cosigner_email, "cannot change after the cosigner has signed")
      end
    end

    def ready_to_submit?
      application_ready_to_submit? && user_ready_to_submit?
    end

    def application_ready_to_submit?
      required_fields = ["name", "description", "address_line1", "address_city", "address_state", "address_postal_code", "address_country", "referrer", "previously_applied"]

      if user.is_minor?
        required_fields.push("cosigner_email")
      end

      unless teen_led?
        required_fields += ["planning_duration", "team_size", "annual_budget", "committed_amount"]

        if committed_amount&.positive?
          required_fields.push("funding_source")
        end
      end

      missing_fields = required_fields.any? do |field|
        self[field].nil? || self[field] == ""
      end

      !missing_fields && !address_country.in?(DISALLOWED_COUNTRIES)
    end

    def user_ready_to_submit?
      required_fields = ["full_name", "phone_number", "birthday"]

      missing_fields = required_fields.any? do |field|
        !user[field].present?
      end

      !missing_fields
    end

  end

end
