# frozen_string_literal: true

# Base that holds all the tables (set AIRTABLE_BASE=app... in your env).
# Tables are referenced by name, so the names below must match your Airtable tabs.
AIRTABLE_BASE = Credentials.fetch(:AIRTABLE_BASE)

Feedback = Airrecord.table(Credentials.fetch(:AIRTABLE), AIRTABLE_BASE, "Feedback")
GWaitlistTable = Airrecord.table(Credentials.fetch(:AIRTABLE), AIRTABLE_BASE, "Google Workspace Waitlist")
ApplicationsTable = Airrecord.table(Credentials.fetch(:AIRTABLE), AIRTABLE_BASE, "Applications")
EmailsTable = Airrecord.table(Credentials.fetch(:AIRTABLE), AIRTABLE_BASE, "Emails")
OnboardersTable = Airrecord.table(Credentials.fetch(:AIRTABLE), AIRTABLE_BASE, "Onboarders")
