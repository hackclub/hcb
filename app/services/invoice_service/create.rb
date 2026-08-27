# frozen_string_literal: true

module InvoiceService
  class Create
    # `line_items` is an array of hashes, each with a `:description` and an
    # `:amount` (in dollars, as accepted by Monetize). For backwards
    # compatibility a single `item_description` / `item_amount` pair is still
    # accepted and treated as a one-line invoice.
    def initialize(event_id:,
                   due_date:,
                   current_user:,
                   sponsor_id:,
                   sponsor_name:, sponsor_email:,
                   sponsor_address_line1:, sponsor_address_line2:,
                   sponsor_address_city:, sponsor_address_state:,
                   sponsor_address_postal_code:,
                   sponsor_address_country:,
                   line_items: nil,
                   item_description: nil, item_amount: nil)
      @event_id = event_id

      @due_date = due_date
      @line_items = line_items
      @item_description = item_description
      @item_amount = item_amount

      @current_user = current_user

      @sponsor_id = sponsor_id
      @sponsor_name = sponsor_name
      @sponsor_email = sponsor_email
      @sponsor_address_line1 = sponsor_address_line1
      @sponsor_address_line2 = sponsor_address_line2
      @sponsor_address_city = sponsor_address_city
      @sponsor_address_state = sponsor_address_state
      @sponsor_address_postal_code = sponsor_address_postal_code
      @sponsor_address_country = sponsor_address_country
    end

    def run
      invoice = nil

      ActiveRecord::Base.transaction do
        sponsor

        invoice = Invoice.create!(attrs)

        remote_invoice = StripeService::Invoice.create(remote_invoice_attrs(invoice:))

        clean_line_items.each do |line_item|
          item = StripeService::InvoiceItem.create(
            customer: sponsor.stripe_customer_id,
            currency: "usd",
            description: line_item[:description],
            amount: line_item[:amount],
            invoice: remote_invoice.id
          )

          invoice.line_items.create!(
            description: line_item[:description],
            amount: line_item[:amount],
            item_stripe_id: item.id
          )

          # Keep the legacy `item_stripe_id` column pointing at the first item.
          invoice.item_stripe_id ||= item.id
        end

        invoice.stripe_invoice_id = remote_invoice.id
        invoice.save!

        remote_invoice.send_invoice

        invoice.sync_remote!
      end

      invoice
    end

    private

    def remote_invoice_attrs(invoice:)
      {
        customer: sponsor.stripe_customer_id,
        auto_advance: invoice.auto_advance,
        collection_method: "send_invoice",
        due_date: invoice.due_date.to_i, # convert to unixtime
        description: invoice.memo,
        status: invoice.status,
        statement_descriptor: invoice.statement_descriptor || "HCB",
        # tax_percent: invoice.tax_percent,
        footer:,
        metadata: { event_id: invoice.event.id },
        payment_settings: {
          payment_method_types:,
        }.compact,
      }
    end

    def payment_method_types
      if total_amount >= Invoice::MAX_CARD_AMOUNT
        ["ach_credit_transfer"]
      else
        # just use the default types
      end
    end

    def footer
      "\n\n\n\n\n"\
        "Need to pay by mailed paper check?\n\n"\
        "Please pay the amount to the order of The Hack Foundation, and include '#{sponsor.event.name} (##{sponsor.event.id})' in the memo. Checks can be mailed to:\n\n"\
        "#{sponsor.event.name} (##{sponsor.event.id}) c/o The Hack Foundation\n"\
        "8605 Santa Monica Blvd #86294\n"\
        "West Hollywood, CA 90069"
    end

    def attrs
      {
        due_date: @due_date,
        item_description: clean_line_items.first[:description],
        item_amount: total_amount,
        sponsor:,
        statement_descriptor: StripeService::StatementDescriptor.format(event.short_name, as: :full),
        creator: @current_user
      }
    end

    def sponsor_attrs
      {
        name: @sponsor_name,
        contact_email: @sponsor_email,
        address_line1: @sponsor_address_line1,
        address_line2: @sponsor_address_line2,
        address_city: @sponsor_address_city,
        address_state: @sponsor_address_state,
        address_postal_code: @sponsor_address_postal_code,
        address_country: @sponsor_address_country
      }
    end

    def clean_line_items
      @clean_line_items ||= begin
        raw = if @line_items.present?
                @line_items
              else
                [{ description: @item_description, amount: @item_amount }]
              end

        items = raw.filter_map do |line_item|
          description = line_item[:description].presence
          amount = line_item[:amount]
          next if description.nil? || amount.blank?

          { description:, amount: Monetize.parse(amount).cents }
        end

        raise ArgumentError, "an invoice needs at least one line item" if items.empty?
        raise ArgumentError, "each line item must be at least $1" if items.any? { |item| item[:amount] < 100 }

        items
      end
    end

    def total_amount
      @total_amount ||= clean_line_items.sum { |line_item| line_item[:amount] }
    end

    def sponsor
      @sponsor ||= begin
        if existing_sponsor
          existing_sponsor.update!(sponsor_attrs)
          existing_sponsor
        else
          event.sponsors.create!(sponsor_attrs)
        end
      end
    end

    def existing_sponsor
      @existing_sponsor ||= event.sponsors.find_by(id: @sponsor_id) || event.sponsors.not_null_slugs.find_by(slug: @sponsor_id)
    end

    def event
      @event ||= Event.find(@event_id)
    end

  end
end
