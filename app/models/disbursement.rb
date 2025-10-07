# frozen_string_literal: true

# == Schema Information
#
# Table name: disbursements
#
#  id                                  :bigint           not null, primary key
#  aasm_state                          :string
#  amount                              :integer
#  deposited_at                        :datetime
#  errored_at                          :datetime
#  in_transit_at                       :datetime
#  name                                :string
#  pending_at                          :datetime
#  rejected_at                         :datetime
#  scheduled_on                        :date
#  should_charge_fee                   :boolean          default(FALSE)
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  destination_subledger_id            :bigint
#  destination_transaction_category_id :bigint
#  event_id                            :bigint
#  fulfilled_by_id                     :bigint
#  requested_by_id                     :bigint
#  source_event_id                     :bigint
#  source_subledger_id                 :bigint
#  source_transaction_category_id      :bigint
#
# Indexes
#
#  index_disbursements_on_destination_subledger_id             (destination_subledger_id)
#  index_disbursements_on_destination_transaction_category_id  (destination_transaction_category_id)
#  index_disbursements_on_event_id                             (event_id)
#  index_disbursements_on_fulfilled_by_id                      (fulfilled_by_id)
#  index_disbursements_on_requested_by_id                      (requested_by_id)
#  index_disbursements_on_source_event_id                      (source_event_id)
#  index_disbursements_on_source_subledger_id                  (source_subledger_id)
#  index_disbursements_on_source_transaction_category_id       (source_transaction_category_id)
#
# Foreign Keys
#
#  fk_rails_...  (destination_transaction_category_id => transaction_categories.id)
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (fulfilled_by_id => users.id)
#  fk_rails_...  (requested_by_id => users.id)
#  fk_rails_...  (source_event_id => events.id)
#  fk_rails_...  (source_transaction_category_id => transaction_categories.id)
#
class Disbursement < ApplicationRecord
  include PgSearch::Model
  pg_search_scope :search_name, against: [:name]

  include AASM
  include Commentable

  include Freezable

  validate on: :create do
    if source_event.financially_frozen?
      errors.add(:base, "This transfer can't be created, #{source_event.name} is currently frozen.")
    end
  end

  has_paper_trail

  include PublicIdentifiable
  set_public_id_prefix :xfr # Transfer

  belongs_to :fulfilled_by, class_name: "User", optional: true
  belongs_to :requested_by, class_name: "User", optional: true

  belongs_to :destination_event, foreign_key: "event_id", class_name: "Event", inverse_of: "incoming_disbursements"
  belongs_to :source_event, class_name: "Event", inverse_of: "outgoing_disbursements"
  belongs_to :event
  belongs_to :source_subledger, class_name: "Subledger", optional: true
  belongs_to :destination_subledger, class_name: "Subledger", optional: true

  has_one :raw_pending_incoming_disbursement_transaction
  has_one :raw_pending_outgoing_disbursement_transaction

  belongs_to(:source_transaction_category, class_name: "TransactionCategory", optional: true)
  belongs_to(:destination_transaction_category, class_name: "TransactionCategory", optional: true)

  has_one :card_grant, required: false

  has_many :t_transactions, class_name: "Transaction", inverse_of: :disbursement

  validates_presence_of :source_event_id,
                        :event_id,
                        :amount,
                        :name

  validates :amount, numericality: { greater_than: 0 }
  validate :events_are_different
  validate :events_are_not_demos, on: :create
  validate :scheduled_on_must_be_in_the_future, on: :create

  scope :processing, -> { in_transit }
  scope :fulfilled, -> { deposited }
  scope :reviewing_or_processing, -> { where(aasm_state: [:reviewing, :pending, :in_transit]) }
  scope :scheduled_for_today, -> { scheduled.where(scheduled_on: ..Date.today) }
  scope :not_scheduled, -> { where(scheduled_on: nil) }

  scope :not_card_grant_related, -> { left_joins(source_subledger: :card_grant, destination_subledger: :card_grant).where("card_grants.id IS NULL AND card_grants_subledgers.id IS NULL") }

  SPECIAL_APPEARANCES = {
    hackathon_grant: {
      title: "Hackathon grant",
      memo: "💰 Hackathon grant from Hack Club",
      css_class: "transaction--fancy",
      icon: "purse",
      qualifier: ->(d) { d.source_event_id == EventMappingEngine::EventIds::HACKATHON_GRANT_FUND }
    },
    winter_hardware_wonderland: {
      title: "Winter Hardware Wonderland grant",
      memo: "❄️ Winter Hardware Wonderland Grant",
      css_class: "transaction--icy",
      icon: "freeze",
      qualifier: ->(d) { d.source_event_id == EventMappingEngine::EventIds::WINTER_HARDWARE_WONDERLAND_GRANT_FUND }
    },
    argosy_grant_2024: {
      title: "Grant from the Argosy Foundation",
      memo: "🤖 Argosy Foundation Rookie / Hardship Grant",
      css_class: "transaction--fancy",
      icon: "sam",
      qualifier: ->(d) { d.source_event_id.in?([EventMappingEngine::EventIds::ARGOSY_GRANT_FUND, EventMappingEngine::EventIds::ARGOSY_GRANT_FUND_2025]) && d.created_at > Date.new(2024, 9, 1) }
    },
    first_transparency_grant: {
      title: "FIRST® Transparency grant",
      memo: "🤖 FIRST® Transparency Grant",
      css_class: "transaction--frc",
      icon: "sam",
      qualifier: ->(d) { d.source_event_id == EventMappingEngine::EventIds::FIRST_TRANSPARENCY_GRANT_FUND }
    }
  }.freeze

  include PublicActivity::Model
  tracked owner: proc{ |controller, record| controller&.current_user }, recipient: proc { |controller, record| record.destination_event }, event_id: proc { |controller, record| record.source_event.id }, only: [:create]

  aasm timestamps: true, whiny_persistence: true do
    state :reviewing, initial: true # Being reviewed by an admin
    state :pending                  # Waiting to be processed by the TX engine
    state :scheduled                # Has been scheduled and will be sent!
    state :in_transit               # Transfer started on remote bank
    state :deposited                # Transfer completed!
    state :rejected                 # Rejected by admin
    state :errored                  # oh no! an error!

    event :mark_approved do
      after do |fulfilled_by|
        update(fulfilled_by:)
        canonical_pending_transactions.update_all(fronted: true)
      end
      transitions from: [:reviewing, :scheduled], to: :pending
    end

    event :mark_in_transit do
      transitions from: [:pending, :scheduled], to: :in_transit
    end

    event :mark_deposited do
      transitions from: :in_transit, to: :deposited
    end

    event :mark_errored do
      after do
        canonical_pending_transactions.each { |cpt| cpt.decline! }
      end
      transitions from: [:pending, :in_transit], to: :errored
    end

    event :mark_rejected do
      after do |fulfilled_by|
        update(fulfilled_by:)
        canonical_pending_transactions.each { |cpt| cpt.decline! }
        create_activity(key: "disbursement.rejected", owner: fulfilled_by)
      end
      transitions from: [:scheduled, :reviewing, :pending], to: :rejected
    end

    event :mark_scheduled do
      after do |fulfilled_by|
        update(fulfilled_by:)
      end
      transitions from: [:pending, :reviewing, :in_review], to: :scheduled
    end

  end

  def approve_by_admin(user)
    if scheduled_on.present?
      mark_scheduled!(user)
    else
      mark_approved!(user)
    end
  end

  def pending_expired?
    local_hcb_code.has_pending_expired?
  end

  # Eagerly create HcbCode object
  after_create :local_hcb_code

  alias_attribute :approved_at, :pending_at

  # Returns the perceived time of the transfer to an event with fronting enabled
  def transferred_at
    # `approved_at` isn't set on some old disbursements, so fall back to `in_transit_at`.
    approved_at || in_transit_at
  end

  def hcb_code
    "HCB-#{TransactionGroupingEngine::Calculate::HcbCode::DISBURSEMENT_CODE}-#{id}"
  end

  def local_hcb_code
    @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
  end

  def canonical_transactions
    @canonical_transactions ||= CanonicalTransaction.where(hcb_code:)
  end

  def canonical_pending_transactions
    @canonical_pending_transactions ||= ::CanonicalPendingTransaction.where(hcb_code:)
  end

  def transactions_helper
    @transactions_helper ||= Disbursement::TransactionsHelper.new(self)
  end

  def processed?
    in_transit? || deposited?
  end

  def fulfilled?
    deposited?
  end

  def filter_data
    {
      exists: true,
      reviewing: reviewing?,
      pending: pending?,
      processing: processed? && !fulfilled?,
      fulfilled: fulfilled?,
      rejected: rejected?,
    }
  end

  def state
    if fulfilled?
      :success
    elsif processed? || pending?
      if destination_event.can_front_balance?
        :success
      else
        :muted
      end
    elsif rejected?
      :error
    elsif scheduled?
      :info
    elsif errored?
      :error
    elsif reviewing?
      :muted
    else
      :info
    end
  end

  alias_method :status, :state

  def v3_api_state
    state_text.underscore
  end

  def v4_api_state
    if reviewing?
      "pending"
    elsif rejected?
      "rejected"
    elsif pending? || in_transit? || deposited?
      "completed"
    else
      aasm.current_state
    end
  end

  def state_text
    if fulfilled?
      "fulfilled"
    elsif processed? || pending?
      if destination_event.can_front_balance?
        "fulfilled"
      else
        "processing"
      end
    elsif rejected? && approved_at.present? # Disbursements that were approved, then rejected
      "canceled"
    elsif rejected?
      "rejected"
    elsif scheduled?
      "scheduled"
    elsif errored?
      "errored"
    elsif reviewing?
      "pending"
    else
      "pending"
    end
  end

  def state_icon
    "checkmark" if fulfilled? || processed? || (pending? && destination_event.can_front_balance?)
  end

  def admin_dropdown_description
    "#{ApplicationController.helpers.render_money amount} for #{name} to #{event.name}"
  end

  def transaction_memo
    "HCB-#{local_hcb_code.short_code}"
  end

  def special_appearance_name
    return nil if canonical_pending_transactions.with_custom_memo.any? || canonical_transactions.with_custom_memo.any?

    SPECIAL_APPEARANCES.each do |key, value|
      return key if value[:qualifier].call(self)
    end

    nil
  end

  def special_appearance
    SPECIAL_APPEARANCES[special_appearance_name]
  end

  def special_appearance?
    !special_appearance_name.nil?
  end

  def special_appearance_memo
    special_appearance&.[](:memo)
  end

  def fee_waived?
    !should_charge_fee?
  end

  private

  def events_are_different
    self.errors.add(:event, "must be different than source event") if event_id == source_event_id && destination_subledger_id == source_subledger_id
  end

  def events_are_not_demos
    self.errors.add(:event, "cannot be a demo event") if event.demo_mode?
    self.errors.add(:source_event, "cannot be a demo event") if source_event.demo_mode?
  end

  def scheduled_on_must_be_in_the_future
    if scheduled_on.present? && scheduled_on.before?(Time.now.end_of_day)
      self.errors.add(:scheduled_on, "must be in the future")
    end
  end

end
