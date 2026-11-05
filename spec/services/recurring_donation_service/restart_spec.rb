# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecurringDonationService::Restart do
  let(:event) { create(:event) }
  let(:recurring_donation) do
    create(:recurring_donation, :canceled, event:, name: "Jane Smith", email: "jane@example.com", amount: 12_34, anonymous: true, fee_covered: true, tax_deductible: false, message: "Keep it up!")
  end

  let(:new_subscription_id) { "sub_restarted" }
  let(:card) { { id: "pm_saved", object: "payment_method", card: { last4: "4242" } } }

  def stripe_subscription(id:, status:, **attributes)
    Stripe::Subscription.construct_from(
      id:,
      status:,
      customer: recurring_donation.stripe_customer_id,
      current_period_end: 1.month.from_now.to_i,
      canceled_at: nil,
      default_payment_method: card,
      latest_invoice: { id: "in_restarted", object: "invoice", payment_intent: { id: "pi_restarted", object: "payment_intent", client_secret: "pi_restarted_secret" } },
      items: { data: [{ id: "si_#{id}", price: { id: "price_#{id}", product: "prod_donations" } }] },
      **attributes
    )
  end

  let(:subscriptions) do
    [
      stripe_subscription(id: recurring_donation.stripe_subscription_id, status: "canceled"),
      stripe_subscription(id: new_subscription_id, status: "active")
    ].index_by(&:id)
  end

  before do
    allow(StripeService::Subscription).to receive(:retrieve) { |params| subscriptions.fetch(params[:id]) }
    allow(StripeService::Price).to receive(:create).and_return(Stripe::Price.construct_from(id: "price_restarted"))
    allow(StripeService::Subscription).to receive(:create).and_return(stripe_subscription(id: new_subscription_id, status: "incomplete"))
    allow(StripeService::Invoice).to receive(:pay).and_return(Stripe::Invoice.construct_from(id: "in_restarted", status: "paid"))
  end

  it "copies the donation onto a new subscription charged to the same card" do
    restarted = described_class.new(recurring_donation).run

    expect(StripeService::Price).to have_received(:create).with(hash_including(unit_amount: 12_34, product: "prod_donations"))
    expect(StripeService::Subscription).to have_received(:create).with(
      hash_including(
        customer: recurring_donation.stripe_customer_id,
        items: [{ price: "price_restarted" }],
        default_payment_method: "pm_saved",
        payment_behavior: "default_incomplete"
      )
    )
    expect(StripeService::Invoice).to have_received(:pay).with("in_restarted", { off_session: true })

    expect(restarted).to be_persisted
    expect(restarted).not_to eq(recurring_donation)
    expect(restarted).to have_attributes(
      event:,
      email: "jane@example.com",
      amount: 12_34,
      anonymous: true,
      fee_covered: true,
      tax_deductible: false,
      stripe_subscription_id: new_subscription_id,
      stripe_customer_id: recurring_donation.stripe_customer_id,
      stripe_status: "active",
      last4: "4242"
    )
    expect(restarted.name(show_anonymous: true)).to eq("Jane Smith")
    expect(restarted.url_hash).not_to eq(recurring_donation.url_hash)
    expect(recurring_donation.reload).to be_canceled
  end

  # The first donation would otherwise repeat a message the organizers have
  # already seen.
  it "doesn't copy the message" do
    expect(described_class.new(recurring_donation).run.message).to be_nil
  end

  # `invoice.paid` is dropped if its subscription has no donation yet, so the
  # donation has to be committed before the invoice is paid.
  it "pays the invoice outside the transaction that saves the donation" do
    open_transactions = ActiveRecord::Base.connection.open_transactions

    allow(StripeService::Invoice).to receive(:pay) do
      expect(ActiveRecord::Base.connection.open_transactions).to eq(open_transactions)
      expect(RecurringDonation.exists?(stripe_subscription_id: new_subscription_id)).to be(true)
      Stripe::Invoice.construct_from(id: "in_restarted", status: "paid")
    end

    described_class.new(recurring_donation).run

    expect(StripeService::Invoice).to have_received(:pay)
  end

  it "refuses a donation that hasn't been canceled" do
    recurring_donation.update!(stripe_status: "active", canceled_at: nil)

    expect { described_class.new(recurring_donation).run }.to raise_error(described_class::Error, /Only canceled donations/)
    expect(StripeService::Subscription).not_to have_received(:create)
  end

  it "refuses when the donor already has a live recurring donation to the organization" do
    create(:recurring_donation, event:, email: "jane@example.com", stripe_status: "incomplete")

    expect { described_class.new(recurring_donation).run }
      .to raise_error(described_class::Error, "This donor already has a recurring donation to #{event.name} that's incomplete.")
    expect(StripeService::Subscription).not_to have_received(:create)
    expect(RecurringDonation.count).to eq(2)
  end

  it "ignores the donor's recurring donations to other organizations" do
    create(:recurring_donation, email: "jane@example.com")

    expect(described_class.new(recurring_donation).run).to be_active
  end

  it "refuses when the donation has no saved card" do
    subscriptions[recurring_donation.stripe_subscription_id] = stripe_subscription(id: recurring_donation.stripe_subscription_id, status: "canceled", default_payment_method: nil)

    expect { described_class.new(recurring_donation).run }.to raise_error(described_class::Error, /doesn't have a saved card/)
    expect(StripeService::Subscription).not_to have_received(:create)
    expect(RecurringDonation.count).to eq(1)
  end

  context "when the card is declined" do
    before do
      allow(StripeService::Invoice).to receive(:pay).and_raise(Stripe::CardError.new("Your card was declined.", nil))
      allow(StripeService::Subscription).to receive(:cancel)
      subscriptions[new_subscription_id] = stripe_subscription(id: new_subscription_id, status: "incomplete_expired")
    end

    it "cancels the new subscription and raises" do
      expect { described_class.new(recurring_donation).run }.to raise_error(Stripe::CardError)

      expect(StripeService::Subscription).to have_received(:cancel).with(new_subscription_id)
      expect(RecurringDonation.find_by!(stripe_subscription_id: new_subscription_id)).to be_incomplete_expired
    end
  end
end
