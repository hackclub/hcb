# frozen_string_literal: true

Feedback = Airrecord.table(Rails.application.credentials.dig(:airtable, :pat), "appEzv7w2IBMoxxHe", "tblOmqLjWtJZWXn4O")
GWaitlistTable = Airrecord.table(Rails.application.credentials.dig(:airtable, :pat), "appEzv7w2IBMoxxHe", "tbl9CkfZHKZYrXf1T")
ApplicationsTable = Airrecord.table(Rails.application.credentials.dig(:airtable, :pat), "apppALh5FEOKkhjLR", "tblctmRFEeluG4do7")
