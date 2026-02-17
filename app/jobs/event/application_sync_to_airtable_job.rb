# frozen_string_literal: true

class Event
  class ApplicationSyncToAirtableJob < ApplicationJob
    queue_as :low

    def perform(application)
      return if application.draft?

      app = ApplicationsTable.all(filter: "{recordID} = \"#{application.airtable_record_id}\"").first if application.airtable_record_id.present?
      app ||= ApplicationsTable.all(filter: "{HCB Application ID} = \"#{application.hashid}\"").first
      app ||= ApplicationsTable.new("HCB Application ID" => application.hashid)

      app["First Name"] = application.user.first_name
      app["Last Name"] = application.user.last_name
      app["Email Address"] = application.user.email
      app["Phone Number"] = application.user.phone_number
      app["Date of Birth"] = application.user.birthday
      app["Event Name"] = application.name
      app["Event Website"] = application.website_url
      app["Zip Code"] = application.address_postal_code
      app["Tell us about your event"] = application.description
      app["Have you used HCB for any previous events?"] = application.user.events.any? ? "Yes, I have used HCB before" : "No, first time!"
      app["Teenager Led?"] = application.user.teenager?
      app["Address Line 1"] = application.address_line1
      app["City"] = application.address_city
      app["State"] = application.address_state
      app["Address Country"] = application.address_country
      app["Event Location"] = application.address_country
      app["How did you hear about HCB?"] = application.referrer
      app["Accommodations"] = application.accessibility_notes
      app["(Adults) Political Activity"] = application.political_description
      app["Referral Code"] = application.referral_code
      app["HCB Status"] = application.aasm_state.humanize unless application.draft?
      app["Synced from HCB at"] = Time.current

      app.save

      application.update_columns(airtable_record_id: app.id, airtable_status: app["Status"])
    end

  end

end
