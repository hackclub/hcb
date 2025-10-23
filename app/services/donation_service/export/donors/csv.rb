# frozen_string_literal: true

require "csv"

module DonationService
  module Export
    module Donors
      class Csv
        def initialize(event_id:)
          @event = Event.find(event_id)
        end

        def run
          Enumerator.new do |y|
            y << headers.to_csv

            donors.each do |donor|
              y << row(donor).to_csv
            end
          end
        end

        private

        def donors
          query = <<-SQL
            WITH all_donations AS (
              SELECT COALESCE(d.name, rd.name) as name, COALESCE(d.email, rd.email) as email, d.amount as amount_cents, d.created_at, rd.id as recurring_donation_id
                FROM "donations" d
                LEFT OUTER JOIN "recurring_donations" rd on d.recurring_donation_id = rd.id
                WHERE d.aasm_state = 'deposited'
                AND d.event_id = #{@event.id}
            ),
            latest_names AS (
              SELECT distinct on(email) email, LAST_VALUE(name) OVER (PARTITION BY email ORDER BY created_at ASC) as latest_name
              FROM all_donations
            ),
            donors AS (
              SELECT email, sum(amount_cents) as total_amount_cents, MAX(recurring_donation_id) as latest_recurring_donation_id
              FROM all_donations
              GROUP BY email
            )

            SELECT latest_name, d.email, total_amount_cents, latest_recurring_donation_id
            FROM donors d
            LEFT OUTER JOIN latest_names l on d.email = l.email
          SQL

          ActiveRecord::Base.connection.execute(query)
        end

        def headers
          %w[name email total_amount_cents recurring]
        end

        def row(donor)
          [
            donor["latest_name"],
            donor["email"],
            donor["total_amount_cents"],
            donor["latest_recurring_donation_id"].present? && (RecurringDonation.where(email: donor["email"], event_id: @event.id).active.any? ? "ACTIVE" : "INACTIVE")
          ]
        end

      end
    end
  end
end
