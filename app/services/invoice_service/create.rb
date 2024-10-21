# frozen_string_literal: true

module InvoiceService
  class Create
    def initialize(event_id:,
                   due_date:, item_description:, item_amount:,
                   current_user:,
                   sponsor_id:,
                   sponsor_name:, sponsor_email:,
                   sponsor_address_line1:, sponsor_address_line2:,
                   sponsor_address_city:, sponsor_address_state:,
                   sponsor_address_postal_code:,
                   sponsor_address_country:)
      @event_id = event_id

      @due_date = due_date
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
        item = StripeService::InvoiceItem.create(remote_invoice_item_attrs.merge({ invoice: remote_invoice.id }))

        invoice.item_stripe_id = item.id
        invoice.stripe_invoice_id = remote_invoice.id
        invoice.save!

        remote_invoice.send_invoice

        invoice.sync_remote!
      end

      invoice
    end

    private

    def remote_invoice_item_attrs
      {
        customer: sponsor.stripe_customer_id,
        currency: "usd",
        description: @item_description,
        amount: clean_item_amount
      }
    end

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
      if clean_item_amount >= Invoice::MAX_CARD_AMOUNT
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
        item_description: @item_description,
        item_amount: clean_item_amount,
        sponsor:,
        statement_descriptor: StripeService::StatementDescriptor.format(event.name, as: :full),
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

    def clean_item_amount
      @clean_item_amount ||= Monetize.parse(@item_amount).cents
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
