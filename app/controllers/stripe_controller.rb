# frozen_string_literal: true

class StripeController < ActionController::Base
  protect_from_forgery except: :webhook

  def webhook
    payload = request.body.read
    sig_header = request.headers["Stripe-Signature"]

    begin
      event = StripeService.construct_webhook_event(payload, sig_header)
      method = "handle_#{event["type"].tr(".", "_")}"

      StatsD.measure("StripeController.#{method}") { self.send method, event }
    rescue JSON::ParserError => e
      head :bad_request
      Rails.error.report(e)
      return
    rescue NoMethodError => e
      puts e
      Rails.error.report(e)
      head :ok # success so that stripe doesn't retry (method is unsupported by HCB)
      return
    rescue Stripe::SignatureVerificationError
      head :bad_request
      return
    end
  end

  private

  def handle_issuing_authorization_request(event)
    # fire-and-forget update to grafana dashboard
    StatsD.increment("stripe_webhook_authorization", 1)

    approved = ::StripeAuthorizationService::Webhook::HandleIssuingAuthorizationRequest.new(stripe_event: event).run

    response.set_header "Stripe-Version", "2022-08-01"

    render json: {
      approved:
    }
  end

  def handle_issuing_authorization_created(event)
    auth_id = event[:data][:object][:id]

    # put the transaction on the pending ledger in almost realtime
    ::StripeAuthorization::CreateFromWebhookJob.perform_later(auth_id)

    head :ok
  end

  def handle_issuing_authorization_updated(event)
    is_closed = event[:data][:object][:status] == "closed"
    has_timeout = event[:data][:object][:request_history].pluck(:reason).include?("webhook_timeout")

    StatsD.increment("stripe_webhook_timeout", 1) if is_closed && has_timeout

    rpst = PendingTransactionEngine::RawPendingStripeTransactionService::Stripe::ImportSingle.new(remote_stripe_transaction: event[:data][:object]).run

    # this has been commented out due to a suspected race condition
    # PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::Stripe.new(raw_pending_stripe_transaction: rpst).run

    head :ok
  end

  def handle_issuing_transaction_created(event)
    tx = event[:data][:object]
    amount = tx[:amount]
    return unless amount < 0

    head :ok
  end

  def handle_issuing_card_updated(event)
    card = StripeCard.find_by(stripe_id: event[:data][:object][:id])
    card.sync_from_stripe!
    card.save

    head :ok
  end

  def handle_invoice_paid(event)
    stripe_invoice = event[:data][:object]

    if stripe_invoice.subscription.present?
      RecurringDonationService::HandleInvoicePaid.new(stripe_invoice).run
      return
    end

    invoice = Invoice.find_by(stripe_invoice_id: stripe_invoice[:id])
    return unless invoice

    safely do
      StripeService::Charge.update(
        stripe_invoice[:charge],
        { metadata: { event_id: invoice.event.id } },
      )
    end

    # Mark invoice as paid
    InvoiceService::OpenToPaid.new(invoice_id: invoice.id).run

    unless invoice.manually_marked_as_paid?
      # Import to the ledger
      rpit = ::PendingTransactionEngine::RawPendingInvoiceTransactionService::Invoice::ImportSingle.new(invoice:).run
      cpt = ::PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::Invoice.new(raw_pending_invoice_transaction: rpit).run
      ::PendingEventMappingEngine::Map::Single::Invoice.new(canonical_pending_transaction: cpt).run
    end

    head :ok
  end

  def handle_invoice_payment_failed(event)
    stripe_invoice = event[:data][:object]

    if stripe_invoice.subscription.present?
      recurring_donation = RecurringDonation.find_by!(stripe_subscription_id: stripe_invoice.subscription)
      RecurringDonationMailer.with(recurring_donation:).payment_failed.deliver_later
    end

    head :ok
    return
  end

  def handle_customer_subscription_updated(event)
    recurring_donation = RecurringDonation.find_by(stripe_subscription_id: event.data.object.id)
    return unless recurring_donation

    recurring_donation.sync_with_stripe_subscription!
    recurring_donation.save!
  end

  alias_method :handle_customer_subscription_deleted, :handle_customer_subscription_updated

  def handle_setup_intent_succeeded(event)
    setup_intent = event.data.object
    return unless setup_intent.metadata[:recurring_donation_id]

    suppress(ActiveRecord::RecordNotFound) do
      recurring_donation = RecurringDonation.find(setup_intent.metadata[:recurring_donation_id])
      StripeService::Subscription.update(recurring_donation.stripe_subscription_id, default_payment_method: setup_intent.payment_method)
      recurring_donation.sync_with_stripe_subscription!
      recurring_donation.save!

      RecurringDonationMailer.with(recurring_donation:).payment_method_changed.deliver_later
    end
  end

  def handle_charge_dispute_funds_withdrawn(event)
    # A donor has disputed a charge. Oh no!

    # TODO: properly handle disputes

    dispute = event[:data][:object]

    payment_intent = StripeService::PaymentIntent.retrieve(dispute[:payment_intent])

    if payment_intent.metadata[:donation].present?
      # It's a donation

      donation = Donation.find_by(stripe_payment_intent_id: dispute[:payment_intent])

      return notify_airbrake("Received charge dispute on nonexistent donation") if donation.nil?

      # Let's un-front the transaction.
      donation.canonical_pending_transactions.update_all(fronted: false)
    else
      # It's an invoice

      invoice = Invoice.find_by(stripe_charge_id: dispute[:charge])

      return notify_airbrake("Received charge dispute on nonexistent invoice") if invoice.nil?

      invoice.canonical_pending_transactions.update_all(fronted: false)
    end

    head :ok
  end

  def handle_charge_refunded(event)
    charge = event[:data][:object]

    donation = Donation.find_by(stripe_payment_intent_id: charge[:payment_intent])
    invoice = Invoice.find_by(stripe_charge_id: charge[:id])

    if donation
      donation.mark_refunded! unless donation.refunded?

      StripeService::Topup.create(
        amount: charge[:amount_refunded],
        currency: "usd",
        description: "Refund for donation #{donation.id}",
        statement_descriptor: "HCB-#{donation.local_hcb_code.short_code}"
      )
    elsif invoice
      invoice.mark_refunded! unless invoice.refunded_v2?

      StripeService::Topup.create(
        amount: charge[:amount_refunded],
        currency: "usd",
        description: "Refund for invoice #{invoice.id}",
        statement_descriptor: "HCB-#{invoice.local_hcb_code.short_code}"
      )
    end
  end

  def handle_payment_intent_succeeded(event)
    # only proceed if payment intent is a donation and not an invoice
    return unless event.data.object.metadata[:donation].present?

    # get donation to process
    donation = event.data.object.metadata[:donation_id].present? ? Donation.find_by_public_id(event.data.object.metadata[:donation_id]) : Donation.find_by_stripe_payment_intent_id(event.data.object.id)

    unless donation.stripe_payment_intent_id.present?
      donation.update(stripe_payment_intent_id: event.data.object.id)
    end

    pi = StripeService::PaymentIntent.retrieve(
      id: donation.stripe_payment_intent_id,
      expand: ["charges.data.balance_transaction", "latest_charge.balance_transaction", "latest_charge.payment_method_details"]
    )
    donation.set_fields_from_stripe_payment_intent(pi)
    donation.save!

    donation.send_receipt!

    # Import the donation onto the ledger
    rpdt = ::PendingTransactionEngine::RawPendingDonationTransactionService::Donation::ImportSingle.new(donation:).run
    cpt = ::PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::Donation.new(raw_pending_donation_transaction: rpdt).run
    ::PendingEventMappingEngine::Map::Single::Donation.new(canonical_pending_transaction: cpt).run
  end

  def handle_charge_updated(event)
    # only proceed if charge is related to a donation and not an invoice
    return unless event.data.object.metadata[:donation].present?

    # get donation to process
    donation = Donation.find_by_stripe_payment_intent_id(event.data.object[:payment_intent])

    pi = StripeService::PaymentIntent.retrieve(
      id: donation.stripe_payment_intent_id,
      expand: ["latest_charge.balance_transaction"]
    )
    donation.set_fields_from_stripe_payment_intent(pi)
    donation.save!
  end

  def handle_payout_updated(event)
    payout = DonationPayout.find_by(stripe_payout_id: event.data.object.id) || InvoicePayout.find_by(stripe_payout_id: event.data.object.id)
    return unless payout

    payout.set_fields_from_stripe_payout(event.data.object)
    payout.save!
  end

  alias_method :handle_payout_canceled, :handle_payout_updated
  alias_method :handle_payout_failed, :handle_payout_updated
  alias_method :handle_payout_paid, :handle_payout_updated

  def handle_issuing_personalization_design_updated(event)
    design = StripeCard::PersonalizationDesign.find_by(stripe_id: event.data.object.id)
    return unless design

    design.sync_from_stripe!
  end

  def handle_issuing_personalization_design_rejected(event)
    design = StripeCard::PersonalizationDesign.find_by(stripe_id: event.data.object.id)
    return unless design

    design.sync_from_stripe!

    if design.event&.stripe_card_logo&.attached? # if the logo is no longer attached it's already been rejected.
      StripeCard::PersonalizationDesignMailer.with(event: design.event, reason: event.data.object["rejection_reasons"]["card_logo"].first).design_rejected.deliver_later
      design.event.stripe_card_personalization_designs.update(stale: true)
      design.event.stripe_card_logo.delete
    end
  end

  alias_method :handle_issuing_personalization_design_activated, :handle_issuing_personalization_design_updated
  alias_method :handle_issuing_personalization_design_deactivated, :handle_issuing_personalization_design_updated

  def handle_issuing_dispute_funds_reinstated(event)
    dispute = event.data.object
    transaction = Stripe::Issuing::Transaction.retrieve(dispute["transaction"])
    hcb_code = RawPendingStripeTransaction.find_by!(stripe_transaction_id: transaction["authorization"]).canonical_pending_transaction.local_hcb_code
    if dispute["status"] == "won" && dispute["currency"] == "usd"
      StripeService::Payout.create(
        amount: dispute["amount"],
        currency: dispute["currency"],
        statement_descriptor: "HCB-#{hcb_code.short_code}",
        source_balance: "issuing",
        metadata: {
          dispute_id: dispute["id"],
          authorization_id: transaction["authorization"],
          hcb_code: hcb_code.hcb_code
        }
      )
    elsif dispute["status"] != "won"
      Airbrake.notify("Dispute with funds reinstated but without a win: #{dispute["id"]}")
    elsif dispute["currency"] != "usd"
      Airbrake.notify("Dispute with funds reinstated but non-USD currency. Must be manually handled.")
    end
  end

  def handle_refund_failed(event)
    Airbrake.notify("Refund failed on Stripe: #{event}.")
  end

end
