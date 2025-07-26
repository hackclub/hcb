# frozen_string_literal: true

# == Schema Information
#
# Table name: stripe_authorizations
#
#  id                           :bigint           not null, primary key
#  amount                       :integer
#  approved                     :boolean          default(FALSE), not null
#  authorization_method         :integer
#  display_name                 :string
#  marked_no_or_lost_receipt_at :datetime
#  name                         :string
#  stripe_status                :integer
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  stripe_card_id               :bigint           not null
#  stripe_id                    :text
#
# Indexes
#
#  index_stripe_authorizations_on_stripe_card_id  (stripe_card_id)
#
# Foreign Keys
#
#  fk_rails_...  (stripe_card_id => stripe_cards.id)
#
class StripeAuthorization < ApplicationRecord
  include Receiptable

  before_validation :sync_from_stripe! # pull details from stripe if we're creating it for the first time. expensive in the webhook. TODO: adjust - ideally async after authorization approved or not

  default_scope { order(created_at: :desc) }
  scope :awaiting_receipt, -> { missing_receipt.where.not(amount: 0).where(approved: true) }
  scope :unified_list, -> { approved.where.not(stripe_status: :reversed) }
  scope :approved, -> { where(approved: true) }
  scope :declined, -> { where(approved: false) }
  scope :successful, -> { approved.closed }
  scope :renamed, -> { where("display_name != name") }

  def awaiting_receipt?
    !amount.zero? && approved && missing_receipt?
  end

  def declined?
    approved == false
  end

  has_paper_trail

  belongs_to :stripe_card, class_name: "StripeCard"
  alias_method :card, :stripe_card
  has_one :stripe_cardholder, through: :stripe_card, as: :cardholder
  alias_method :cardholder, :stripe_cardholder
  has_one :user, through: :stripe_cardholder
  has_one :event, through: :stripe_card

  enum :stripe_status, { pending: 0, closed: 1, reversed: 2 }
  enum :authorization_method, { keyed_in: 0, swipe: 1, chip: 2, contactless: 3, online: 4 }

  validates_uniqueness_of :stripe_id

  validates_presence_of :stripe_id, :stripe_status, :authorization_method, :amount, :name

  def filter_data
    {
      exists: true,
      fee_applies: false,
      fee_payment: false,
      card: true
    }
  end

  def status_emoji
    return "✔️" if approved?

    "✖️"
  end

  def status_text
    return "Declined" unless approved?
    return "Pending" if pending?
    return "Refunded" if reversed?
    return "Approved" if approved?

    "–"
  end

  def status_color
    return :error unless approved?
    return :muted if pending?
    return :warning if reversed?
    return :success if approved?

    :accent
  end

  def authorization_method_text
    (stripe_obj[:wallet] || authorization_method).humanize
  end

  def merchant_name
    @merchant_name ||= name || stripe_obj[:merchant_data][:name]
  end

  def merchant_data
    @merchant_data ||= stripe_obj[:merchant_data]
  end

  def sync_from_stripe!
    puts "syncing from stripe"
    self.stripe_id = stripe_obj[:id]
    self.stripe_status = stripe_obj[:status]
    self.authorization_method = stripe_obj[:authorization_method]
    self.approved = stripe_obj[:approved]
    self.amount = stripe_obj[:amount]
    self.name = stripe_obj[:merchant_data][:name]

    stripe_card_id = stripe_obj[:card][:id]
    self.stripe_card = StripeCard.find_by(stripe_id: stripe_card_id)

    # (max@maxwofford.com) https://github.com/hackclub/hcb/issues/1031
    # This is a chaotic way of solving #1031 (tl;dr, stripe doesn't
    # consistently tell us if a tx was refunded). We're going to deviate from
    # the status stripe is telling us and mark it as 'refunded' if all the
    # authorization's transactions sum to 0.
    # if (stripe_obj[:status] == 'closed' && stripe_obj[:transactions].size >= 1)
    if stripe_obj[:transactions].size >= 1
      net_amount = -stripe_obj[:transactions].pluck(:amount).sum # must be negated since the rest of stripe_authorizations is treating positives as negatives in the interface
      self.amount = net_amount
      self.stripe_status = "reversed" if net_amount.zero?
    end
  end

  def stripe_obj
    @stripe_auth_obj ||= StripeService::Issuing::Authorization.retrieve(stripe_id)
  rescue => e
    { number: "XXXX", cvc: "XXX", created: Time.now.utc.to_i,
      merchant_data: {
        name: "XXX"
      }
    }
  end

  def remote_stripe_transaction_amount_cents
    @remote_stripe_transaction_amount_cents ||= remote_stripe_transactions.map(&:amount).sum
  end

  def date
    created_at
  end

  def memo
    name
  end

  def deleted_at
    nil
  end

  private

  def remote_stripe_transactions
    @remote_stripe_transactions ||= begin
      remote_stripe_authorization["transactions"].map do |t|
        ::Stripe::Issuing::Transaction.retrieve(t.id)
      end
    end
  end

  def remote_stripe_authorization
    @remote_stripe_authorization ||= ::StripeService::Issuing::Authorization.retrieve(stripe_id)
  end

end
