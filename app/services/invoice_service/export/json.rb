# frozen_string_literal: true

require "json"

module InvoiceService
  module Export
    class Json
      def initialize(invoices:)
        @invoices = invoices.includes(:sponsor)
      end

      def run
        @invoices.map { |invoice| row(invoice) }.to_json
      end

      private

      def row(i)
        {
          created_at: i.created_at,
          due_date: i.due_date,
          status: i.state_text,
          paid: i.paid_v2? || i.manually_marked_as_paid?,
          sponsor_name: i.sponsor.name,
          sponsor_email: i.sponsor.contact_email,
          description: i.item_description,
          amount_cents: i.item_amount
        }
      end

    end
  end
end
