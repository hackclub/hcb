# frozen_string_literal: true

# == Schema Information
#
# Table name: recurring_donations
#
#  id                                  :bigint           not null, primary key
#  amount                              :integer
#  canceled_at                         :datetime
#  email                               :text
#  last4_ciphertext                    :text
#  migrated_from_legacy_stripe_account :boolean          default(FALSE)
#  name                                :text
#  stripe_client_secret                :text
#  stripe_current_period_end           :datetime
#  stripe_status                       :text
#  url_hash                            :text
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  event_id                            :bigint           not null
#  stripe_customer_id                  :text
#  stripe_payment_intent_id            :text
#  stripe_subscription_id              :text
#
# Indexes
#
#  index_recurring_donations_on_event_id                (event_id)
#  index_recurring_donations_on_stripe_subscription_id  (stripe_subscription_id) UNIQUE
#  index_recurring_donations_on_url_hash                (url_hash) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class RecurringDonation < ApplicationRecord
  include Hashid::Rails

  has_paper_trail

  belongs_to :event
  has_many :donations

  has_encrypted :last4

  before_create :create_stripe_subscription, unless: -> { stripe_subscription_id.present? }
  before_create :assign_unique_hash

  before_update :update_amount, if: -> { amount_changed? }
  after_update :notify_amount_changed!, if: -> { amount_previously_changed? }

  validates :name, :email, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 100, less_than_or_equal_to: 999_999_99 }
  validates_uniqueness_of :stripe_subscription_id
  validates_uniqueness_of :email,
                          scope: :event_id,
                          on: :create,
                          conditions: -> { where(stripe_status: "active") },
                          message: ->(recurring_donation, data) { "You're already donating to #{recurring_donation.event.name}." }

  # TODO: suffix: false is the default setting but we are explicitly passing it here
  # to silence a Ruby 3 warning in Ruby 2.7. We can remove it once Ruby 3 upgrade is complete
  enum :stripe_status, {
    active: "active",
    past_due: "past_due",
    unpaid: "unpaid",
    canceled: "canceled",
    incomplete: "incomplete",
    incomplete_expired: "incomplete_expired",
    trialing: "trialing" # y'know... free trials... for donations
  }, suffix: false

  def stripe_subscription
    @stripe_subscription ||= StripeService::Subscription.retrieve(
      id: stripe_subscription_id,
      expand: ["latest_invoice.payment_intent", "default_payment_method"]
    )
  end

  def sync_with_stripe_subscription!(subscription = stripe_subscription)
    self.stripe_subscription_id = subscription.id
    self.stripe_payment_intent_id = subscription.latest_invoice&.payment_intent&.id
    self.stripe_client_secret = subscription.latest_invoice&.payment_intent&.client_secret
    self.stripe_current_period_end = Time.at(subscription.current_period_end)
    self.stripe_status = subscription.status
    self.last4 = subscription.default_payment_method&.card&.last4
    self.canceled_at = Time.at(subscription.canceled_at) if subscription.canceled_at
    self.stripe_customer_id = subscription.customer

    self
  end

  def status_badge_color
    case stripe_status
    when "active"
      "success"
    when "canceled"
      "muted"
    when "past_due"
      "warning"
    when "unpaid"
      "warning"
    when "incomplete"
      "warning"
    when "incomplete_expired"
      "warning"
    else
      "muted"
    end
  end

  def cancel!
    StripeService::Subscription.cancel(stripe_subscription_id)
    sync_with_stripe_subscription!
    save!

    RecurringDonationMailer.with(recurring_donation: self).canceled.deliver_later
  end

  def total_donated
    if donations.loaded?
      donations.records.sum(&:amount)
    else
      donations.sum(:amount)
    end
  end

  private

  def create_stripe_subscription
    if Rails.env.development?
      test_clock = StripeService::TestHelpers::TestClock.create(frozen_time: Time.now.to_i)
      customer = StripeService::Customer.create(
        email: email,
        name: name,
        test_clock: test_clock.id
      )
    else
      customer = StripeService::Customer.create(
        email: email,
        name: name,
      )
    end

    price = StripeService::Price.create(
      currency: "usd",
      unit_amount: amount,
      recurring: { interval: "month" },
      product_data: { name: "Recurring donation to #{event.name}", statement_descriptor: StripeService::StatementDescriptor.format(event.name) }
    )

    subscription = StripeService::Subscription.create(
      customer: customer.id,
      items: [
        { price: price.id }
      ],
      payment_behavior: "default_incomplete",
      payment_settings: { save_default_payment_method: "on_subscription" },
      expand: ["latest_invoice.payment_intent", "default_payment_method"]
    )

    sync_with_stripe_subscription!(subscription)
  end

  def assign_unique_hash
    self.url_hash = SecureRandom.hex(8)
  end

  def update_amount
    return if canceled?

    # Create the new price
    price = StripeService::Price.create(
      currency: "usd",
      unit_amount: amount,
      recurring: { interval: "month" },
      product: stripe_subscription.items.data.first.price.product
    )

    # Connect the subscription to the new price
    StripeService::Subscription.update(
      stripe_subscription_id,
      {
        proration_behavior: "none",
        items: [
          {
            id: stripe_subscription.items.data.first.id,
            price: price.id
          }
        ]
      }
    )
  end

  def notify_amount_changed!
    RecurringDonationMailer.with(recurring_donation: self, previous_amount: amount_previously_was).amount_changed.deliver_later
  end

end
