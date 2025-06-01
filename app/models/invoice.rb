# frozen_string_literal: true

# == Schema Information
#
# Table name: invoices
#
#  id                                                           :bigint           not null, primary key
#  aasm_state                                                   :string
#  amount_due                                                   :bigint
#  amount_paid                                                  :bigint
#  amount_remaining                                             :bigint
#  archived_at                                                  :datetime
#  attempt_count                                                :bigint
#  attempted                                                    :boolean
#  auto_advance                                                 :boolean
#  due_date                                                     :datetime
#  ending_balance                                               :bigint
#  finalized_at                                                 :datetime
#  hcb_code                                                     :text
#  hosted_invoice_url                                           :text
#  invoice_pdf                                                  :text
#  item_amount                                                  :bigint
#  item_description                                             :text
#  livemode                                                     :boolean
#  manually_marked_as_paid_at                                   :datetime
#  manually_marked_as_paid_reason                               :text
#  memo                                                         :text
#  number                                                       :text
#  payment_method_ach_credit_transfer_account_number_ciphertext :text
#  payment_method_ach_credit_transfer_bank_name                 :text
#  payment_method_ach_credit_transfer_routing_number            :text
#  payment_method_ach_credit_transfer_swift_code                :text
#  payment_method_card_brand                                    :text
#  payment_method_card_checks_address_line1_check               :text
#  payment_method_card_checks_address_postal_code_check         :text
#  payment_method_card_checks_cvc_check                         :text
#  payment_method_card_country                                  :text
#  payment_method_card_exp_month                                :text
#  payment_method_card_exp_year                                 :text
#  payment_method_card_funding                                  :text
#  payment_method_card_last4                                    :text
#  payment_method_type                                          :text
#  payout_creation_balance_available_at                         :datetime
#  payout_creation_balance_net                                  :integer
#  payout_creation_balance_stripe_fee                           :integer
#  payout_creation_queued_at                                    :datetime
#  payout_creation_queued_for                                   :datetime
#  reimbursable                                                 :boolean          default(TRUE)
#  slug                                                         :text
#  starting_balance                                             :bigint
#  statement_descriptor                                         :text
#  status                                                       :text
#  subtotal                                                     :bigint
#  tax                                                          :bigint
#  tax_percent                                                  :decimal(, )
#  total                                                        :bigint
#  void_v2_at                                                   :datetime
#  created_at                                                   :datetime         not null
#  updated_at                                                   :datetime         not null
#  archived_by_id                                               :bigint
#  creator_id                                                   :bigint
#  fee_reimbursement_id                                         :bigint
#  item_stripe_id                                               :text
#  manually_marked_as_paid_user_id                              :bigint
#  payout_creation_queued_job_id                                :text
#  payout_id                                                    :bigint
#  sponsor_id                                                   :bigint
#  stripe_charge_id                                             :text
#  stripe_invoice_id                                            :text
#  voided_by_id                                                 :bigint
#
# Indexes
#
#  index_invoices_on_archived_by_id                   (archived_by_id)
#  index_invoices_on_creator_id                       (creator_id)
#  index_invoices_on_fee_reimbursement_id             (fee_reimbursement_id)
#  index_invoices_on_item_stripe_id                   (item_stripe_id) UNIQUE
#  index_invoices_on_manually_marked_as_paid_user_id  (manually_marked_as_paid_user_id)
#  index_invoices_on_payout_creation_queued_job_id    (payout_creation_queued_job_id) UNIQUE
#  index_invoices_on_payout_id                        (payout_id)
#  index_invoices_on_slug                             (slug) UNIQUE
#  index_invoices_on_sponsor_id                       (sponsor_id)
#  index_invoices_on_status                           (status)
#  index_invoices_on_stripe_invoice_id                (stripe_invoice_id) UNIQUE
#  index_invoices_on_voided_by_id                     (voided_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (archived_by_id => users.id)
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (fee_reimbursement_id => fee_reimbursements.id)
#  fk_rails_...  (manually_marked_as_paid_user_id => users.id)
#  fk_rails_...  (payout_id => invoice_payouts.id)
#  fk_rails_...  (sponsor_id => sponsors.id)
#  fk_rails_...  (voided_by_id => users.id)
#
class Invoice < ApplicationRecord
  MAX_CARD_AMOUNT = 10_000_00 # Maximum amount we allow to be paid via credit card, in cents

  has_paper_trail skip: [:payment_method_ach_credit_transfer_account_number] # ciphertext columns will still be tracked
  has_encrypted :payment_method_ach_credit_transfer_account_number

  include PublicIdentifiable
  set_public_id_prefix :inv

  include HasStripeDashboardUrl
  has_stripe_dashboard_url "invoices", :stripe_invoice_id

  extend FriendlyId
  include AASM

  include Freezable

  include PublicActivity::Model
  tracked owner: proc{ |controller, record| controller&.current_user }, event_id: proc { |controller, record| record.event.id }, only: [:create]

  include PgSearch::Model
  pg_search_scope :search_description, associated_against: { sponsor: :name }, against: [:item_description, :item_amount], using: { tsearch: { prefix: true, dictionary: "english" } }, ranked_by: "invoices.created_at"

  scope :unarchived, -> { where(archived_at: nil).where.not(aasm_state: "void_v2", manually_marked_as_paid_at: nil) }
  scope :archived, -> { where.not(archived_at: nil).where.not(aasm_state: "void_v2", manually_marked_as_paid_at: nil) }
  scope :missing_fee_reimbursement, -> { where(fee_reimbursement_id: nil) }
  scope :missing_payout, -> { where("payout_id is null and payout_creation_balance_net is not null") } # some invoices are missing a payout but it is ok because they were paid by check. that is why we additionally check on payout_creation_balance_net
  scope :unpaid, -> { where("aasm_state != 'paid_v2'").where("aasm_state != 'void_v2'") }
  scope :past_due, -> { where("due_date < ?", Time.current) }
  scope :voided, -> { where(aasm_state: "void_v2") }
  scope :not_manually_marked_as_paid, -> { where(manually_marked_as_paid_at: nil) }
  scope :missing_raw_pending_invoice_transaction, -> { joins("LEFT JOIN raw_pending_invoice_transactions ON raw_pending_invoice_transactions.invoice_transaction_id = invoices.id::text").where(raw_pending_invoice_transactions: { id: nil }) }

  friendly_id :slug_text, use: :slugged

  # Raise this when attempting to do an operation with the associated Stripe
  # charge, but it doesn't exist, like in the case of trying to create a payout
  # for an invoice that was so low that no charge was created on Stripe's end
  # (ex. for $0.10).
  class NoAssociatedStripeCharge < StandardError; end

  belongs_to :sponsor
  accepts_nested_attributes_for :sponsor
  has_one :event, through: :sponsor

  belongs_to :creator, class_name: "User"
  belongs_to :manually_marked_as_paid_user, class_name: "User", optional: true
  belongs_to :payout, class_name: "InvoicePayout", optional: true
  belongs_to :fee_reimbursement, optional: true
  belongs_to :archived_by, class_name: "User", optional: true
  belongs_to :voided_by, class_name: "User", optional: true

  has_one :personal_transaction, class_name: "HcbCode::PersonalTransaction", required: false
  has_one_attached :manually_marked_as_paid_attachment

  aasm timestamps: true do
    state :open_v2, initial: true
    state :paid_v2
    state :void_v2
    state :refunded_v2

    event :mark_paid do
      transitions from: :open_v2, to: :paid_v2
      after do
        create_activity(key: "invoice.paid", owner: nil)
      end
    end

    event :mark_void do
      transitions from: :open_v2, to: :void_v2
    end

    event :mark_refunded do
      transitions from: :paid_v2, to: :refunded_v2
    end
  end

  enum :status, {
    draft: "draft", # only 3 invoices [203, 204, 128] leftover from when drafts existed
    open: "open",
    paid: "paid",
    void: "void"
  }

  validates_presence_of :item_description, :item_amount, :due_date

  validate :due_date_cannot_be_in_past, on: :create

  validates :item_amount, numericality: { greater_than_or_equal_to: 100, message: "must be at least $1" }

  before_create :set_defaults

  after_create_commit -> {
    unless OrganizerPosition.find_by(user: self.creator, event: event)&.manager?
      InvoiceMailer.with(invoice: self).notify_organizers_sent.deliver_later
    end
  }

  # Stripe syncing…
  before_destroy :close_stripe_invoice

  def pending_expired?
    local_hcb_code.has_pending_expired?
  end

  def fee_reimbursed?
    !fee_reimbursement.nil?
  end

  def manually_marked_as_paid?
    manually_marked_as_paid_at.present?
  end

  def payout_transaction
    self.payout&.t_transaction
  end

  def completed_deprecated?
    (payout_transaction && !self.fee_reimbursement) || (payout_transaction && self.fee_reimbursement&.t_transaction) || manually_marked_as_paid?
  end

  def archived?
    archived_at.present?
  end

  def deposited? # TODO move to aasm
    canonical_transactions.count >= 2 || manually_marked_as_paid? || completed_deprecated?
  end

  def state
    return :success if paid_v2? && deposited?
    return :success if paid_v2? && event.can_front_balance?
    return :success if manually_marked_as_paid?
    return :info if paid_v2?
    return :error if void_v2?
    return :info if refunded_v2?
    return :muted if archived?
    return :error if due_date < Time.current
    return :warning if due_date < 3.days.from_now

    :muted
  end

  def state_text
    return "Deposited" if paid_v2? && (event.can_front_balance? || deposited?)
    return "In Transit" if paid_v2?
    return "Paid" if manually_marked_as_paid?
    return "Voided" if void_v2?
    return "Refunded" if refunded_v2?
    return "Archived" if archived?
    return "Overdue" if due_date < Time.current
    return "Due soon" if due_date < 3.days.from_now

    "Sent"
  end

  def state_icon
    return "checkmark" if deposited? || (paid_v2? && event.can_front_balance?)
  end

  def filter_data
    {
      exists: true,
      paid: paid?,
      unpaid: !paid?,
      upcoming: due_date > 3.days.from_now,
      overdue: due_date < 3.days.from_now && !paid?,
      archived: archived?
    }
  end

  def set_fields_from_stripe_invoice(inv = remote_invoice)
    self.amount_due = inv.amount_due
    self.amount_paid = inv.amount_paid
    self.amount_remaining = inv.amount_remaining
    self.attempt_count = inv.attempt_count
    self.attempted = inv.attempted
    self.auto_advance = inv.auto_advance
    self.due_date = Time.at(inv.due_date).to_datetime # convert from unixtime
    self.ending_balance = inv.ending_balance
    self.finalized_at = inv.respond_to?(:status_transitions) ? inv.status_transitions.finalized_at : inv.try(:finalized_at)
    self.hosted_invoice_url = inv.hosted_invoice_url
    self.invoice_pdf = inv.invoice_pdf
    self.livemode = inv.livemode
    self.memo = inv.description
    self.number = inv.number
    self.starting_balance = inv.starting_balance
    self.statement_descriptor = inv.statement_descriptor
    self.status = inv.status
    self.stripe_charge_id = inv&.charge&.id
    self.subtotal = inv.subtotal
    self.tax = inv.tax
    # self.tax_percent = inv.tax_percent
    self.total = inv.total
    # https://stripe.com/docs/api/charges/object#charge_object-payment_method_details
    self.payment_method_type = type = inv&.charge&.payment_method_details&.type
    return unless self.payment_method_type

    details = inv&.charge&.payment_method_details&.[](self.payment_method_type)
    return unless details

    case type
    when "card"
      self.payment_method_card_brand = details.brand
      self.payment_method_card_checks_address_line1_check = details.checks.address_line1_check
      self.payment_method_card_checks_address_postal_code_check = details.checks.address_postal_code_check
      self.payment_method_card_checks_cvc_check = details.checks.cvc_check
      self.payment_method_card_country = details.country
      self.payment_method_card_exp_month = details.exp_month
      self.payment_method_card_exp_year = details.exp_year
      self.payment_method_card_funding = details.funding
      self.payment_method_card_last4 = details.last4
    when "ach_credit_transfer"
      self.payment_method_ach_credit_transfer_bank_name = details.bank_name
      self.payment_method_ach_credit_transfer_routing_number = details.routing_number
      self.payment_method_ach_credit_transfer_account_number = details.account_number
      self.payment_method_ach_credit_transfer_swift_code = details.swift_code
    end
  end

  def arrival_date
    arrival = self.payout&.arrival_date || 3.business_days.after(payout_creation_queued_for)

    # Add 1 day to account for plaid and Bank processing time
    arrival + 1.day
  end

  def arriving_late?
    DateTime.now > self.arrival_date
  end

  def stripe_obj
    @stripe_obj ||= StripeService::Invoice.retrieve(stripe_invoice_id).to_hash
  end

  def remote_invoice
    @remote_invoice ||= ::Partners::Stripe::Invoices::Show.new(id: stripe_invoice_id).run
  end

  def paid_at
    timestamp = remote_invoice&.status_transitions&.paid_at
    timestamp ? Time.at(timestamp, in: "UTC") : nil
  end

  def remote_status
    remote_invoice.status
  end

  def remote_paid?
    remote_status == "paid"
  end

  def canonical_pending_transaction
    canonical_pending_transactions.first
  end

  def smart_memo
    sponsor.name
  end

  def hcb_code
    "HCB-#{TransactionGroupingEngine::Calculate::HcbCode::INVOICE_CODE}-#{id}"
  end

  def local_hcb_code
    @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
  end

  def canonical_transactions
    @canonical_transactions ||= CanonicalTransaction.where(hcb_code:)
  end

  def canonical_pending_transactions
    return [] unless raw_pending_invoice_transaction

    @canonical_pending_transactions ||= ::CanonicalPendingTransaction.where(raw_pending_invoice_transaction_id: raw_pending_invoice_transaction)
  end

  def sync_remote!
    set_fields_from_stripe_invoice
    save!
  end

  def close_stripe_invoice
    remote_invoice.void_invoice

    sync_remote!
  end

  private

  def raw_pending_invoice_transaction
    raw_pending_invoice_transactions.first
  end

  def raw_pending_invoice_transactions
    @raw_pending_invoice_transactions ||= ::RawPendingInvoiceTransaction.where(invoice_transaction_id: id)
  end

  def set_defaults
    event = sponsor.event.name
    self.memo = "To support #{event}. #{event} is fiscally sponsored by The Hack Foundation (d.b.a. Hack Club), a 501(c)(3) nonprofit with the EIN 81-2908499."

    self.auto_advance = true
  end

  def due_date_cannot_be_in_past
    if due_date.present? && due_date < Time.current
      errors.add(:due_date, "can't be in the past")
    end
  end

  def slug_text
    "#{self.sponsor.name} #{self.item_description}"
  end

end
