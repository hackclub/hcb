# frozen_string_literal: true

# == Schema Information
#
# Table name: emburse_transfers
#
#  id                     :bigint           not null, primary key
#  accepted_at            :datetime
#  canceled_at            :datetime
#  load_amount            :bigint
#  rejected_at            :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  creator_id             :bigint
#  emburse_card_id        :bigint
#  emburse_transaction_id :string
#  event_id               :bigint
#  fulfilled_by_id        :bigint
#
# Indexes
#
#  index_emburse_transfers_on_creator_id       (creator_id)
#  index_emburse_transfers_on_emburse_card_id  (emburse_card_id)
#  index_emburse_transfers_on_event_id         (event_id)
#  index_emburse_transfers_on_fulfilled_by_id  (fulfilled_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (emburse_card_id => emburse_cards.id)
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (fulfilled_by_id => users.id)
#
class EmburseTransfer < ApplicationRecord
  include Rejectable
  include Commentable

  before_save :normalize_blank_values

  paginates_per 50

  # NOTE(@msw) emburse_transfers used to be on a per-emburse_card basis & we're keeping the
  # association for compatability with migrations
  belongs_to :emburse_card, optional: true

  belongs_to :event
  belongs_to :fulfilled_by, class_name: "User", optional: true
  belongs_to :creator, class_name: "User"
  has_one :t_transaction, class_name: "Transaction"

  validate :status_accepted_canceled_or_rejected
  validates :load_amount, numericality: { greater_than_or_equal_to: 1 }

  default_scope { order(created_at: :desc) }

  scope :under_review, -> { where(rejected_at: nil, canceled_at: nil, accepted_at: nil) }
  scope :accepted, -> { where.not(accepted_at: nil) }
  scope :pending, -> do
    includes(:t_transaction)
      .accepted
      .where(
        emburse_transaction_id: nil,
        transactions: { id: nil }
      )
  end
  scope :unpaired, -> do
    includes(:t_transaction)
      .accepted
      .where(
        transactions: { id: nil }
      )
  end
  scope :completed, -> { accepted.where.not(id: pending) }
  scope :transferred, -> { completed.includes(:t_transaction).where.not(transactions: { id: nil }) }
  scope :canceled, -> { where.not(canceled_at: nil) }
  scope :rejected, -> { where.not(rejected_at: nil) }

  # Return average processing time in days over last_n completed requests rounding up
  def self.processing_time(last_n: 5)
    reqs = EmburseTransfer.transferred.first(last_n)
    processing_times = reqs.map { |r| (r.t_transaction.date.to_time - r.created_at) / 24.hours }

    # round up
    processing_times.present? ? Util.average(processing_times).ceil : "?"
  end

  def status
    return "transfer in progress" if EmburseTransfer.pending.include?(self)
    return "completed" if EmburseTransfer.completed.include?(self)
    return "canceled" if canceled_at.present?
    return "rejected" if rejected_at.present?

    "under review"
  end

  def status_badge_type
    s = status.to_sym
    return :info if s == "transfer in progress".to_sym
    return :success if s == :completed
    return :muted if s == :canceled
    return :error if s == :rejected

    :pending
  end

  def under_review?
    rejected_at.nil? && canceled_at.nil? && accepted_at.nil?
  end

  def pending?
    t_transaction.nil? && emburse_transaction_id.nil? && !accepted_at.nil?
  end

  def unfulfilled?
    fulfilled_by.nil?
  end

  include ApplicationHelper
  def description
    "#{self.id} (#{render_money self.load_amount}, #{time_ago_in_words self.created_at} ago, #{self.event.name})"
  end

  private

  def normalize_blank_values
    attributes.each_key do |column|
      self[column].present? || self[column] = nil
    end
  end

end
