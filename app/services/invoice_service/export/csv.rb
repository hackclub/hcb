# frozen_string_literal: true

require "csv"

module InvoiceService
  module Export
    class Csv
      def initialize(invoices:, by_sponsor: false)
        @invoices = invoices.includes(:sponsor)
        @by_sponsor = by_sponsor # sponsor sort
      end

      def run
        Enumerator.new do |csv|
          if @by_sponsor
            csv << %w[sponsor_name sponsor_email invoice_count total_invoiced total_paid total_unpaid].to_csv

            @invoices.to_a
                     .group_by(&:sponsor)
                     .sort_by { |_sponsor, invoices| -sum(invoices.select { |i| paid?(i) }) }
                     .each { |sponsor, invoices| csv << sponsor_row(sponsor, invoices).to_csv }
          else
            csv << %w[date due_date status paid sponsor_name sponsor_email description amount_cents amount].to_csv

            @invoices.each { |invoice| csv << invoice_row(invoice).to_csv }
          end
        end
      end

      private

      def invoice_row(i)
        [
          i.created_at,
          i.due_date,
          i.state_text,
          paid?(i),
          i.sponsor.name,
          i.sponsor.contact_email,
          i.item_description,
          i.item_amount,
          dollars(i.item_amount)
        ].map { |value| SafeCsv.sanitize(value) }
      end

      def sponsor_row(sponsor, invoices)
        [
          sponsor.name,
          sponsor.contact_email,
          invoices.size,
          dollars(sum(invoices)),
          dollars(sum(invoices.select { |i| paid?(i) })),
          dollars(sum(invoices.select { |i| i.open_v2? && !i.manually_marked_as_paid? }))
        ].map { |value| SafeCsv.sanitize(value) }
      end

      def paid?(invoice)
        invoice.paid_v2? || invoice.manually_marked_as_paid?
      end

      def sum(invoices)
        invoices.sum(&:item_amount)
      end

      def dollars(cents)
        format("%.2f", cents / 100.0)
      end

    end
  end
end
