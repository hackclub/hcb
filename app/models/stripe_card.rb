# frozen_string_literal: true

# == Schema Information
#
# Table name: stripe_cards
#
#  id                                    :bigint           not null, primary key
#  canceled_at                           :datetime
#  card_type                             :integer          default("virtual"), not null
#  cash_withdrawal_enabled               :boolean          default(FALSE)
#  initially_activated                   :boolean          default(FALSE), not null
#  is_platinum_april_fools_2023          :boolean
#  last4                                 :text
#  lost_in_shipping                      :boolean          default(FALSE)
#  name                                  :string
#  purchased_at                          :datetime
#  spending_limit_amount                 :integer
#  spending_limit_interval               :integer
#  stripe_brand                          :text
#  stripe_exp_month                      :integer
#  stripe_exp_year                       :integer
#  stripe_shipping_address_city          :text
#  stripe_shipping_address_country       :text
#  stripe_shipping_address_line1         :text
#  stripe_shipping_address_line2         :text
#  stripe_shipping_address_postal_code   :text
#  stripe_shipping_address_state         :text
#  stripe_shipping_name                  :text
#  stripe_status                         :text
#  created_at                            :datetime         not null
#  updated_at                            :datetime         not null
#  event_id                              :bigint           not null
#  replacement_for_id                    :bigint
#  stripe_card_personalization_design_id :integer
#  stripe_cardholder_id                  :bigint           not null
#  stripe_id                             :text
#  subledger_id                          :bigint
#
# Indexes
#
#  index_stripe_cards_on_event_id              (event_id)
#  index_stripe_cards_on_replacement_for_id    (replacement_for_id)
#  index_stripe_cards_on_stripe_cardholder_id  (stripe_cardholder_id)
#  index_stripe_cards_on_stripe_id             (stripe_id) UNIQUE
#  index_stripe_cards_on_subledger_id          (subledger_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (stripe_cardholder_id => stripe_cardholders.id)
#
class StripeCard < ApplicationRecord
  include Hashid::Rails
  include PublicIdentifiable
  include Freezable
  set_public_id_prefix :crd

  include HasStripeDashboardUrl
  has_stripe_dashboard_url "issuing/cards", :stripe_id

  has_paper_trail

  validate :within_card_limit, on: :create

  after_create_commit :notify_user, unless: :skip_notify_user

  attr_accessor :skip_notify_user

  scope :deactivated, -> { where.not(stripe_status: "active") }
  scope :canceled, -> { where(stripe_status: "canceled") }
  scope :frozen, -> { where(stripe_status: "inactive") }
  scope :active, -> { where(stripe_status: "active") }
  scope :physical_shipping, -> { physical.includes(:user, :event).reject { |c| c.stripe_obj[:shipping][:status] == "delivered" } }
  scope :platinum, -> { where(is_platinum_april_fools_2023: true) }

  scope :on_main_ledger, -> { where(subledger_id: nil) }

  belongs_to :event
  belongs_to :subledger, optional: true
  belongs_to :stripe_cardholder
  belongs_to :replacement_for, class_name: "StripeCard", optional: true
  belongs_to :personalization_design, foreign_key: "stripe_card_personalization_design_id", class_name: "StripeCard::PersonalizationDesign", optional: true
  has_one :replacement, class_name: "StripeCard", foreign_key: :replacement_for_id
  alias_method :cardholder, :stripe_cardholder
  has_one :user, through: :stripe_cardholder
  has_many :stripe_authorizations
  alias_method :authorizations, :stripe_authorizations
  alias_method :transactions, :stripe_authorizations
  alias_attribute :platinum, :is_platinum_april_fools_2023

  has_one :card_grant, required: false

  alias_attribute :last_four, :last4

  enum :card_type, { virtual: 0, physical: 1 }
  enum :spending_limit_interval, { daily: 0, weekly: 1, monthly: 2, yearly: 3, per_authorization: 4, all_time: 5 }

  delegate :stripe_name, to: :stripe_cardholder

  validates_uniqueness_of :stripe_id

  validates_presence_of :stripe_shipping_address_city,
                        :stripe_shipping_address_country,
                        :stripe_shipping_address_line1,
                        :stripe_shipping_address_postal_code,
                        :stripe_shipping_name,
                        unless: -> { self.virtual? }

  validates_presence_of :stripe_cardholder_id,
                        :card_type,
                        :stripe_id,
                        :stripe_brand,
                        :stripe_exp_month,
                        :stripe_exp_year,
                        :last4,
                        :stripe_status,
                        if: -> { self.stripe_id.present? }

  validate :only_physical_cards_can_be_lost_in_shipping
  validate :only_physical_cards_can_have_personalization_design
  validate :personalization_design_must_be_of_the_same_event
  validates_length_of :name, maximum: 40

  before_save do
    self.canceled_at = Time.now if stripe_status_changed?(to: "canceled")
  end

  def full_card_number
    secret_details[:number]
  end

  def cvc
    secret_details[:cvc]
  end

  def url
    Airbrake.notify("StripeCard#url used")
    "/stripe_cards/#{hashid}"
  end

  def popover_path
    "/stripe_cards/#{hashid}?frame=true"
  end

  def formatted_card_number
    return hidden_card_number_with_last_four unless virtual?

    full_card_number.scan(/.{4}/).join(" ")
  end

  def hidden_card_number
    "•••• •••• •••• ••••"
  end

  def hidden_cvc
    "•••"
  end

  def hidden_card_number_with_last_four
    return hidden_card_number unless initially_activated?

    "•••• •••• •••• #{last4}"
  end

  def total_spent
    # pending authorizations + settled transactions
    RawPendingStripeTransaction
      .pending
      .where("stripe_transaction->'card'->>'id' = ?", stripe_id)
      .sum(:amount_cents).abs + canonical_transactions.sum(:amount_cents).abs
  end

  def status_text
    return "Frozen" if stripe_status == "inactive" && initially_activated?

    stripe_status.humanize
  end

  alias :state_text :status_text

  def status_badge_type
    s = stripe_status.to_sym
    return :success if s == :active
    return :error if s == :deleted
    return :warning if s == :inactive && !initially_activated?

    :muted
  end

  def state
    status_badge_type
  end

  def freeze!
    StripeService::Issuing::Card.update(self.stripe_id, status: :inactive)
    sync_from_stripe!
    save!
  end

  def defrost!
    StripeService::Issuing::Card.update(self.stripe_id, status: :active)
    sync_from_stripe!
    save!
  end

  def cancel!
    StripeService::Issuing::Card.update(self.stripe_id, status: :canceled)
    sync_from_stripe!
    save!
    card_grant.cancel! if card_grant&.active?
  end

  def frozen?
    initially_activated? && stripe_status == "inactive"
  end

  def last_frozen_by
    user_id = versions.where_object_changes_to(stripe_status: "inactive").last&.whodunnit
    return nil unless user_id

    User.find_by_id(user_id)
  end

  def active?
    stripe_status == "active"
  end

  def deactivated?
    stripe_status != "active"
  end

  def canceled?
    stripe_status == "canceled"
  end

  include ActiveModel::AttributeMethods
  alias_attribute :address_line1, :stripe_shipping_address_line1
  alias_attribute :address_line2, :stripe_shipping_address_line2
  alias_attribute :address_city, :stripe_shipping_address_city
  alias_attribute :address_state, :stripe_shipping_address_state
  alias_attribute :address_country, :stripe_shipping_address_country
  alias_attribute :address_postal_code, :stripe_shipping_address_postal_code

  def stripe_obj
    @stripe_obj ||= ::Stripe::Issuing::Card.retrieve(id: stripe_id)
  rescue => e
    RecursiveOpenStruct.new({ number: "XXXX", cvc: "XXX", created: Time.now.utc.to_i, shipping: { status: "delivered", carrier: "USPS", eta: 2.weeks.ago, tracking_number: "12345678s9" } })
  end

  def secret_details
    @secret_details ||= ::Stripe::Issuing::Card.retrieve(id: stripe_id, expand: ["cvc", "number"])
  rescue => e
    OpenStruct.new({ number: "XXXX", cvc: "XXX" })
  end

  def shipping_has_tracking?
    stripe_obj&.shipping&.tracking_number&.present?
  end

  def shipping_eta
    return unless (stripe_eta = stripe_obj&.shipping&.eta)

    # We've found Stripe's ETA for USPS standard is fairly inaccurate. So, I'm
    # padding their estimate to set more realistic expectations for our users.
    Time.at(stripe_eta) + 2.days
  end

  def self.new_from_stripe_id(params)
    raise ArgumentError.new("Only numbers are allowed") unless params[:stripe_id].is_a?(String)

    card = self.new(params)
    card.sync_from_stripe!

    card
  end

  def sync_from_stripe!
    if stripe_obj[:deleted]
      self.stripe_status = "deleted"
      return self
    end
    self.stripe_id = stripe_obj[:id]
    self.stripe_brand = stripe_obj[:brand]
    self.stripe_exp_month = stripe_obj[:exp_month]
    self.stripe_exp_year = stripe_obj[:exp_year]
    self.last4 = stripe_obj[:last4]
    self.stripe_status = stripe_obj[:status]
    self.card_type = stripe_obj[:type]
    self.stripe_card_personalization_design_id = StripeCard::PersonalizationDesign.find_by(stripe_id: stripe_obj[:personalization_design])&.id

    if stripe_obj[:status] == "active"
      self.initially_activated = true
    elsif stripe_obj[:status] == "inactive" && !self.initially_activated
      self.initially_activated = false
    end

    if stripe_obj[:shipping]
      if ["returned", "failure"].include?(stripe_obj[:shipping][:status]) && !lost_in_shipping?
        self.lost_in_shipping = true
        StripeCardMailer.with(card_id: self.id).lost_in_shipping.deliver_later

        # force a refresh of the cache; otherwise, the card will be marked as
        # lost in shipping again since stripe_obj is cached
        @stripe_obj = nil
        self.cancel!

        # `cancel!` calls `sync_from_stripe!`, so there is no need to continue
        return self
      end
      self.stripe_shipping_address_city = stripe_obj[:shipping][:address][:city]
      self.stripe_shipping_address_country = stripe_obj[:shipping][:address][:country]
      self.stripe_shipping_address_line1 = stripe_obj[:shipping][:address][:line1]
      self.stripe_shipping_address_postal_code = stripe_obj[:shipping][:address][:postal_code]
      self.stripe_shipping_address_line2 = stripe_obj[:shipping][:address][:line2]
      self.stripe_shipping_address_state = stripe_obj[:shipping][:address][:state]
      self.stripe_shipping_name = stripe_obj[:shipping][:name]
    end

    spending_limits = stripe_obj[:spending_controls][:spending_limits]
    if spending_limits.any?
      self.spending_limit_interval = spending_limits.first[:interval]
      self.spending_limit_amount = spending_limits.first[:amount]
    end

    if stripe_obj[:replacement_for]
      self.replacement_for = StripeCard.find_by(stripe_id: stripe_obj[:replacement_for])
    end

    self
  end

  def canonical_transactions
    @canonical_transactions ||= CanonicalTransaction.stripe_transaction.where("raw_stripe_transactions.stripe_transaction->>'card' = ?", stripe_id)
  end

  def hcb_codes
    all_hcb_codes = canonical_transaction_hcb_codes + canonical_pending_transaction_hcb_codes
    if Flipper.enabled?(:transaction_tags_2022_07_29, self.event)
      @hcb_codes ||= ::HcbCode.where(hcb_code: all_hcb_codes).includes(:tags)
    else
      @hcb_codes ||= ::HcbCode.where(hcb_code: all_hcb_codes)
    end
  end

  def remote_shipping_status
    return nil if virtual?

    stripe_obj[:shipping][:status]
  end

  def canonical_pending_transaction_hcb_codes
    CanonicalPendingTransaction.joins(:raw_pending_stripe_transaction)
                               .where("raw_pending_stripe_transactions.stripe_transaction->'card'->>'id' = ?", stripe_id)
                               .pluck(:hcb_code)
  end

  def active_spending_control
    return @active_spending_control if defined?(@active_spending_control)

    @active_spending_control = event.organizer_positions.find_by(user:)&.active_spending_control
  end

  def balance_available
    if subledger.present?
      subledger.balance_cents
    elsif active_spending_control
      [active_spending_control.balance_cents, event.balance_available_v2_cents].min
    else
      event.balance_available_v2_cents
    end
  end

  def expired?
    Time.now.utc > Time.new(stripe_exp_year, stripe_exp_month).end_of_month
  end

  def ephemeral_key(nonce:)
    Stripe::EphemeralKey.create({ nonce:, issuing_card: stripe_id }, { stripe_version: "2020-03-02" })
  end

  private

  def canonical_transaction_hcb_codes
    @canonical_transaction_hcb_codes ||= canonical_transactions.pluck(:hcb_code)
  end

  def issued?
    stripe_id.present?
  end

  def notify_user
    if virtual?
      StripeCardMailer.with(card_id: self.id).virtual_card_ordered.deliver_later
    else
      StripeCardMailer.with(card_id: self.id).physical_card_ordered.deliver_later
    end
  end

  def authorizations_from_stripe
    @auths ||= begin
      result = []
      auths = StripeService::Issuing::Authorization.list(card: stripe_id)
      auths.auto_paging_each { |auth| result << auth }
      result
    end

    @auths
  end

  def only_physical_cards_can_be_lost_in_shipping
    if !physical? && lost_in_shipping?
      errors.add(:lost_in_shipping, "can only be true for physical cards")
    end
  end

  def only_physical_cards_can_have_personalization_design
    if !physical? && personalization_design.present?
      errors.add(:personalization_design, "can only be add to for physical cards")
    end
  end

  def personalization_design_must_be_of_the_same_event
    if personalization_design&.event.present? && personalization_design.event != event
      errors.add(:personalization_design, "must be of the same event")
    end
  end

  def within_card_limit
    return if subledger.present?

    # card grants don't count against the limit, hence the subledger_id: nil check
    user_cards_today = user.stripe_cards.where(subledger_id: nil, created_at: 1.day.ago..).count
    event_cards_today = event.stripe_cards.where(subledger_id: nil, created_at: 1.day.ago..).count

    if user_cards_today > 20
      errors.add(:base, "Your account has been rate-limited from creating new cards. Please try again tomorrow; for help, email hcb@hackclub.com.")
    end

    if event_cards_today > 20
      errors.add(:base, "Your organization has been rate-limited from creating new cards. Please try again tomorrow; for help, email hcb@hackclub.com.")
    end
  end

end
