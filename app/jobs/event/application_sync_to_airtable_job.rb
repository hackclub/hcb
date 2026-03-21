# frozen_string_literal: true

class Event
  class ApplicationSyncToAirtableJob < ApplicationJob
    queue_as :low

    def perform(application)
      @application = application
      return if @application.draft?

      # If Airtable record already exists, update it and move on! (no concerns for race conditions)
      airrecord = @application.airtable_record
      return update_airtable(airrecord) if airrecord.present?

      # Airtable record doesn't exist, let's create it! Lock Application to prevent duplicate new Airtable records
      @application.with_lock do
        airrecord = @application.airtable_record # Check again for Airtable record (inside lock)
        airrecord ||= ApplicationsTable.new("HCB Application ID" => @application.hashid)

        update_airtable(airrecord)
      end
    end

    def update_airtable(airrecord)
      airrecord["First Name"] = @application.user.first_name
      airrecord["Last Name"] = @application.user.last_name
      airrecord["Email Address"] = @application.user.email
      airrecord["Phone Number"] = @application.user.phone_number
      airrecord["Date of Birth"] = @application.user.birthday
      airrecord["Event Name"] = @application.name
      airrecord["Event Website"] = @application.website_url
      airrecord["Zip Code"] = @application.address_postal_code
      airrecord["Tell us about your event"] = @application.description
      airrecord["Have you used HCB for any previous events?"] = @application.user.events.any? ? "Yes, I have used HCB before" : "No, first time!"
      airrecord["Teenager Led?"] = @application.teen_led?
      airrecord["Address Line 1"] = @application.address_line1
      airrecord["Address Line 2"] = @application.address_line2
      airrecord["City"] = @application.address_city
      airrecord["State"] = @application.address_state
      airrecord["Address Country"] = @application.address_country
      airrecord["Event Location"] = @application.address_country
      airrecord["Team Size"] = @application.team_size
      airrecord["Planning Duration"] = @application.planning_duration
      airrecord["Currently fiscally sponsored?"] = @application.currently_fiscally_sponsored? ? "Yes" : "No"
      airrecord["Previously applied?"] = @application.currently_fiscally_sponsored? ? "Yes" : "No"
      airrecord["Committed Amount"] = @application.committed_amount.to_f if @application.committed_amount.present?
      airrecord["Annual Budget"] = @application.annual_budget.to_f if @application.annual_budget.present?
      airrecord["Funding Source"] = @application.funding_source
      airrecord["How did you hear about HCB?"] = @application.referrer
      airrecord["Accommodations"] = @application.accessibility_notes
      airrecord["Political Activity"] = @application.political_description
      airrecord["Referral Code"] = @application.referral_code
      airrecord["HCB Status"] = @application.aasm_state.humanize unless @application.draft?
      airrecord["Synced from HCB at"] = Time.current

      if @application.affiliations.any?(&:is_first?)
        airrecord["Org Type"] = "FIRST/Robotics"
      elsif @application.affiliations.any?(&:is_vex?)
        airrecord["Org Type"] = "Robotics"
      elsif @application.affiliations.any?(&:is_hack_club?)
        airrecord["Org Type"] = "Hack Club"
      end

      if @application.event.present?
        airrecord["HCB ID"] = @application.event.id
        airrecord["HCB account URL"] = Rails.application.routes.url_helpers.event_url(@application.event)
      end

      airrecord.save

      # Updating airtable_synced_at prevents infinite looping this job
      @application.update!(airtable_record_id: airrecord.id, airtable_status: airrecord["Status"], airtable_synced_at: DateTime.now)
    end

  end

end
