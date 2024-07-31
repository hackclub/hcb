# frozen_string_literal: true

require "csv"

module DonationService
  module Export
    module Donors
      class Csv
        BATCH_SIZE = 1000

        def initialize(event_id:)
          @event_id = event_id
        end

        def run
          Enumerator.new do |y|
            y << header.to_s

            donors.each do |donor|
              y << row(donor).to_s
            end
          end
        end

        # private

        def donors
          query = <<-SQL
            WITH all_donations AS (
              SELECT COALESCE(d.name, rd.name) as name, COALESCE(d.email, rd.email) as email, d.amount as amount_cents, d.created_at
                FROM "donations" d
                LEFT OUTER JOIN "recurring_donations" rd on d.recurring_donation_id = rd.id
                WHERE d.aasm_state = 'deposited'
                AND d.event_id = #{event.id}
            ),
            latest_names AS (
              SELECT distinct on(email) email, LAST_VALUE(name) OVER (PARTITION BY email ORDER BY created_at ASC) as latest_name
              FROM all_donations
            ),
            donors AS (
              SELECT email, sum(amount_cents) as total_amount_cents
              FROM all_donations
              GROUP BY email
            )

            SELECT latest_name, d.email, total_amount_cents
            FROM donors d
            LEFT OUTER JOIN latest_names l on d.email = l.email
          SQL

          results = ActiveRecord::Base.connection.execute(query)
        end

        def event
          @event ||= Event.find(@event_id)
        end

        def header
          ::CSV::Row.new(headers, ["name", "email", "total_amount_cents"], true)
        end

        def row(donor)
          ::CSV::Row.new(headers, [donor["latest_name"], donor["email"], donor["total_amount_cents"]], true)
        end

        def headers
          [
            :name,
            :email,
            :total_donated,
          ]
        end

      end
    end
  end
end
