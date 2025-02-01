# frozen_string_literal: true

# == Schema Information
#
# Table name: card_grants
#
#  id              :bigint           not null, primary key
#  amount_cents    :integer
#  category_lock   :string
#  email           :string           not null
#  keyword_lock    :string
#  merchant_lock   :string
#  status          :integer          default("active"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  disbursement_id :bigint
#  event_id        :bigint           not null
#  sent_by_id      :bigint           not null
#  stripe_card_id  :bigint
#  subledger_id    :bigint
#  user_id         :bigint           not null
#
# Indexes
#
#  index_card_grants_on_disbursement_id  (disbursement_id)
#  index_card_grants_on_event_id         (event_id)
#  index_card_grants_on_sent_by_id       (sent_by_id)
#  index_card_grants_on_stripe_card_id   (stripe_card_id)
#  index_card_grants_on_subledger_id     (subledger_id)
#  index_card_grants_on_user_id          (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (sent_by_id => users.id)
#  fk_rails_...  (stripe_card_id => stripe_cards.id)
#  fk_rails_...  (subledger_id => subledgers.id)
#  fk_rails_...  (user_id => users.id)
#
class CardGrant < ApplicationRecord
  include Hashid::Rails
  has_paper_trail

  include PublicIdentifiable
  set_public_id_prefix :cdg

  belongs_to :event
  belongs_to :subledger, optional: true
  belongs_to :stripe_card, optional: true
  belongs_to :user, optional: true
  belongs_to :sent_by, class_name: "User"
  belongs_to :disbursement, optional: true
  has_many :disbursements, ->(record) { where(destination_subledger_id: record.subledger_id) }, through: :event
  has_one :card_grant_setting, through: :event, required: true
  alias_method :setting, :card_grant_setting

  enum :status, { active: 0, canceled: 1, expired: 2 }, default: :active

  before_validation :create_card_grant_setting, on: :create
  before_create :create_user
  before_create :create_subledger
  after_create :transfer_money
  after_create_commit :send_email

  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }
  normalizes :email, with: ->(email) { email.presence&.strip&.downcase }

  delegate :balance, to: :subledger

  serialize :merchant_lock, coder: CommaSeparatedCoder # convert comma-separated merchant list to an array
  serialize :category_lock, coder: CommaSeparatedCoder

  validates_presence_of :amount_cents, :email
  validates :amount_cents, numericality: { greater_than: 0, message: "can't be zero!" }

  scope :not_activated, -> { active.where(stripe_card_id: nil) }
  scope :activated, -> { active.where.not(stripe_card_id: nil) }
  scope :search_recipient, ->(q) { joins(:user).where("users.full_name ILIKE :query OR card_grants.email ILIKE :query", query: "%#{User.sanitize_sql_like(q)}%") }
  scope :expired_before, ->(date) { joins(:card_grant_setting).where("card_grants.created_at + (card_grant_settings.expiration_preference * interval '1 day') < ?", date) }
  scope :expires_on, ->(date) { joins(:card_grant_setting).where("card_grants.created_at + (card_grant_settings.expiration_preference * interval '1 day') = ?", date) }

  monetize :amount_cents

  def name
    "#{user.name} (#{user.email})"
  end

  def state
    if canceled? || expired?
      "muted"
    elsif pending_invite?
      "info"
    elsif stripe_card.frozen?
      "info"
    else
      "success"
    end
  end

  def state_text
    if canceled?
      "Canceled"
    elsif expired?
      "Expired"
    elsif pending_invite?
      "Invitation sent"
    elsif stripe_card.frozen?
      "Frozen"
    else
      "Active"
    end
  end

  def pending_invite?
    stripe_card.nil?
  end

  def topup!(amount_cents:, topped_up_by: User.find(sent_by_id))
    raise ArgumentError.new("Topups must be positive.") unless amount_cents.positive?

    custom_memo = "Topup of grant to #{user.name}"

    ActiveRecord::Base.transaction do
      update!(amount_cents: self.amount_cents + amount_cents)
      disbursement = DisbursementService::Create.new(
        source_event_id: event_id,
        destination_event_id: event_id,
        name: custom_memo,
        amount: amount_cents / 100.0,
        destination_subledger_id: subledger_id,
        requested_by_id: topped_up_by.id,
      ).run

      disbursement.local_hcb_code.canonical_transactions.each { |ct| ct.update!(custom_memo:) }
      disbursement.local_hcb_code.canonical_pending_transactions.each { |cpt| cpt.update!(custom_memo:) }
    end
  end

  def topup_disbursements
    Disbursement.where(destination_subledger_id: subledger.id).where.not(id: disbursement_id)
  end

  def visible_hcb_codes
    ((stripe_card&.hcb_codes || []) + topup_disbursements.map(&:local_hcb_code)).sort_by(&:created_at)
  end

  def expire!
    hcb_user = User.find_by!(email: "bank@hackclub.com")
    cancel!(hcb_user, expired: true)
  end

  def zero!(custom_memo: "Return of funds from grant to #{user.name}", requested_by: User.find_by!(email: "bank@hackclub.com"), allow_topups: false)
    raise ArgumentError, "card grant should have a non-zero balance" if balance.zero?
    raise ArgumentError, "card grant should have a positive balance" unless balance.positive? || allow_topups

    return topup!(amount_cents: balance.cents * -1, topped_up_by: requested_by) if balance.negative?

    disbursement = DisbursementService::Create.new(
      source_event_id: event_id,
      destination_event_id: event_id,
      name: custom_memo,
      amount: balance.amount,
      source_subledger_id: subledger_id,
      requested_by_id: requested_by.id,
    ).run
    disbursement.local_hcb_code.canonical_transactions.each { |ct| ct.update!(custom_memo:) }
    disbursement.local_hcb_code.canonical_pending_transactions.each { |cpt| cpt.update!(custom_memo:) }
  end

  def cancel!(canceled_by = User.find_by!(email: "bank@hackclub.com"), expired: false)
    raise ArgumentError, "Grant is already #{status}" unless active?

    zero!(custom_memo: "Return of funds from #{expired ? "expiration" : "cancellation"} of grant to #{user.name}", requested_by: canceled_by) if balance > 0

    update!(status: :canceled) unless expired
    update!(status: :expired) if expired

    stripe_card&.cancel!
  end

  def create_stripe_card(session)
    return if stripe_card.present?

    self.stripe_card = StripeCardService::Create.new(
      card_type: "virtual",
      event_id:,
      current_user: user,
      current_session: session,
      subledger:,
    ).run

    save!
  end

  def allowed_merchants
    (merchant_lock + (setting&.merchant_lock || [])).uniq
  end

  def allowed_merchant_names
    allowed_merchants.map { |merchant_id| YellowPages::Merchant.lookup(network_id: merchant_id).name || "Unnamed Merchant (#{merchant_id})" }.uniq
  end

  def allowed_categories
    (category_lock + (setting&.category_lock || [])).uniq
  end

  def allowed_category_names
    allowed_categories.map { |category| YellowPages::Category.lookup(key: category).name || "#{category}*" }.uniq
  end

  def keyword_lock
    super || setting&.keyword_lock
  end

  def expires_after
    card_grant_setting.read_attribute_before_type_cast(:expiration_preference)
  end

  def expires_on
    created_at + expires_after.days
  end

  def last_user_change_to(...)
    user_id = versions.where_object_changes_to(...).last&.whodunnit

    user_id && User.find(user_id)
  end

  def last_time_change_to(...)
    versions.where_object_changes_to(...).last&.created_at
  end

  private

  def create_card_grant_setting
    CardGrantSetting.find_or_create_by!(event_id:)
  end

  def create_user
    self.user = User.create_with(creation_method: :card_grant).find_or_create_by!(email:)
  end

  def create_subledger
    self.subledger = event.subledgers.create!
  end

  def transfer_money
    self.disbursement = DisbursementService::Create.new(
      source_event_id: event_id,
      destination_event_id: event_id,
      name: "Grant to #{user.email}",
      amount: amount.amount,
      requested_by_id: sent_by_id,
      destination_subledger_id: subledger_id,
    ).run
    save!
  end

  def send_email
    CardGrantMailer.with(card_grant: self).card_grant_notification.deliver_later
  end

end
