# frozen_string_literal: true

# == Schema Information
#
# Table name: exports
#
#  id              :bigint           not null, primary key
#  parameters      :jsonb
#  type            :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  requested_by_id :bigint
#
# Indexes
#
#  index_exports_on_requested_by_id  (requested_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (requested_by_id => users.id)
#
class Export
  module Event
    # Like `Export::Event::Balances`, but balances are computed purely from
    # settled `CanonicalTransaction`s mapped through `CanonicalEventMapping`
    # (the v2 transaction engine). Pending transactions, fronted balances and
    # `Ledger::Item`s are all excluded.
    class CanonicalTransactionBalances < Export
      store_accessor :parameters, :end_date

      def async?
        true
      end

      def label
        "Canonical transaction balances for all events"
      end

      def filename
        [
          "hcb_canonical_transaction_balances",
          end_date.present? ? "ending_#{end_date}" : nil,
          "exported_#{Time.now.strftime("%Y-%m-%d_%H-%M")}.csv"
        ].compact.join("_")
      end

      def mime_type
        "text/csv"
      end

      def content
        e = Enumerator.new do |y|
          y << header.to_s

          events.find_each do |event|
            y << row(event).to_s
          end
        end

        e.reduce(:+)
      end

      private

      def events
        ::Event.all.not_demo_mode.includes(:plan, :config, :users)
      end

      def header
        SafeCsv::Row.new(headers, headers.map(&:to_s), true)
      end

      def row(event)
        SafeCsv::Row.new(
          headers,
          [
            event.id,
            event.name,
            event.postal_code,
            event.config.contact_email,
            event.users.pluck(:email).join(", "),
            event.plan.revenue_fee_label,
            Rails.application.routes.url_helpers.url_for(event),
            incoming_cents[event.id].to_i + outgoing_cents[event.id].to_i,
            incoming_cents[event.id].to_i,
            outgoing_cents[event.id].to_i,
            event.omit_stats?
          ]
        )
      end

      def headers
        [:id, :name, :postal_code, :contact_email, :organizers, :revenue_fee, :url, :balance, :settled_incoming, :settled_outgoing, :omitted]
      end

      def incoming_cents
        @incoming_cents ||= sum_canonical_transactions("canonical_transactions.amount_cents > 0")
      end

      def outgoing_cents
        @outgoing_cents ||= sum_canonical_transactions("canonical_transactions.amount_cents < 0")
      end

      # Sums `CanonicalTransaction` amounts per event using the event mappings
      # on the main ledger, mirroring `Event#settled_balance_cents`.
      def sum_canonical_transactions(amount_condition)
        mappings = CanonicalEventMapping.on_main_ledger
                                        .joins(:canonical_transaction)
                                        .where(amount_condition)

        mappings = mappings.where("canonical_transactions.date <= ?", Date.parse(end_date)) if end_date.present?

        mappings.group(:event_id).sum("canonical_transactions.amount_cents")
      end

    end
  end

end
