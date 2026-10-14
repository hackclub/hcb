# frozen_string_literal: true

class Event
  # HCB's Book of Business for Mel, Paul, Georgia, and Meagan

  # Keeps one Airtable record per full fiscal sponsorship (7%) organization,
  # with how much it has raised and how much fee revenue it has brought to HCB.

  class SyncRevenueToAirtableJob < ApplicationJob
    queue_as :low

    POINTS_OF_CONTACT = {
      "Paul"    => "usr_notLKl",
      "Mel"     => "usr_wVtRav",
      "Georgia" => "usr_dQtDZB",
      "Meagan"  => "usr_51toVJw",
    }.freeze

    ROBOTICS_POINT_OF_CONTACT = "Georgia"

    def perform
      records = OrganizationRevenueTable.all.index_by { |record| record["HCB ID"] }

      events.find_each(batch_size: 100) do |event|
        record = records[event.public_id] || OrganizationRevenueTable.new("HCB ID" => event.public_id)

        record["Organization"] = event.name
        record["Raised YTD"] = event.raised_ytd_cents / 100.0
        record["Profit YTD"] = fees_cents(event, since: Date.current.beginning_of_year) / 100.0
        record["Profit All Time"] = fees_cents(event) / 100.0
        record["POC (HCB)"] = event.point_of_contact&.name
        record["POC"] = airtable_point_of_contact(event)

        record.save
      rescue Airrecord::Error => e
        Rails.error.report(e, context: { event_id: event.public_id })
      end
    end

    private

    def events
      standard = Event.not_demo_mode.joins(:plan).where(event_plans: { type: Event::Plan::Standard.name })
      robotics_teams = Event.joins(:event_tags).where(event_tags: { name: EventTag::Tags::ROBOTICS_TEAM }).select(:id)

      standard.where(point_of_contact: User.where_public_id(POINTS_OF_CONTACT.values.compact))
              .or(standard.where(id: robotics_teams))
              .includes(:point_of_contact)
    end

    def fees_cents(event, since: nil)
      # Fiscal sponsorship fees charged by the fee engine, at whatever rate the
      # organization was on at the time. Manual fees (e.g. wire fees) are excluded.
      fees = event.fees.revenue
      fees = fees.joins(canonical_event_mapping: :canonical_transaction).where(canonical_transactions: { date: since.. }) if since

      fees.sum(:amount_cents_as_decimal).ceil
    end

    def airtable_point_of_contact(event)
      return ROBOTICS_POINT_OF_CONTACT if event.robotics_team?

      POINTS_OF_CONTACT.key(event.point_of_contact&.public_id)
    end

  end

end
