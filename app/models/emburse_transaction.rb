# frozen_string_literal: true

# == Schema Information
#
# Table name: emburse_transactions
#
#  id                           :bigint           not null, primary key
#  amount                       :integer
#  category_code                :text
#  category_name                :text
#  category_parent              :text
#  category_url                 :text
#  deleted_at                   :datetime
#  emburse_card_uuid            :string
#  label                        :text
#  location                     :text
#  marked_no_or_lost_receipt_at :datetime
#  merchant_address             :text
#  merchant_city                :text
#  merchant_mcc                 :integer
#  merchant_mid                 :bigint
#  merchant_name                :text
#  merchant_state               :text
#  merchant_zip                 :text
#  note                         :text
#  notified_admin_at            :datetime
#  receipt_filename             :text
#  receipt_url                  :text
#  state                        :integer
#  transaction_time             :datetime
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  category_emburse_id          :text
#  emburse_card_id              :bigint
#  emburse_department_id        :string
#  emburse_id                   :string
#  event_id                     :bigint
#
# Indexes
#
#  index_emburse_transactions_on_deleted_at       (deleted_at)
#  index_emburse_transactions_on_emburse_card_id  (emburse_card_id)
#  index_emburse_transactions_on_event_id         (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (emburse_card_id => emburse_cards.id)
#  fk_rails_...  (event_id => events.id)
#
class EmburseTransaction < ApplicationRecord
  include Receiptable
  include Commentable

  enum :state, { "pending" => 0, "completed" => 1, "declined" => 2 }

  acts_as_paranoid
  validates_as_paranoid

  paginates_per 100

  scope :undeclined, -> { where.not(state: "declined") }
  scope :under_review, -> { where(event_id: nil).undeclined }
  scope :awaiting_receipt, -> { missing_receipt.completed.where.not(amount: 0) }
  scope :unified_list, -> { undeclined }

  belongs_to :event, optional: true
  belongs_to :emburse_card, optional: true
  alias_method :card, :emburse_card

  validates_uniqueness_of_without_deleted :emburse_id

  def receipt_required?
    false # Emburse isn't used anymore
  end

  def awaiting_receipt?
    !amount.zero? && approved && missing_receipt?
  end

  def self.during(start_time, end_time)
    self.where(["emburse_transactions.transaction_time >= ? and emburse_transactions.transaction_time <= ?", start_time, end_time])
  end

  def date
    transaction_time
  end

  def memo
    @memo ||= begin
      return "Transfer from bank account" if amount > 0

      merchant_name || "Transfer back to bank account"
    end
  end

  def transfer?
    @transfer ||= amount > 0 || merchant_name.nil?
  end

  def under_review?
    self.event_id.nil? && undeclined?
  end

  def undeclined?
    state != "declined"
  end

  def completed?
    state == "completed"
  end

  def emburse_path
    "https://app.emburse.com/transactions/#{emburse_id}"
  end

  def filter_data
    {
      exists: true,
      fee_applies: false,
      fee_payment: false,
      card: true
    }
  end

  def status_badge_type
    s = state.to_sym
    return :success if s == :completed
    return :error if s == :declined

    :pending
  end

  def status_text
    s = state.to_sym
    return "Completed" if s == :completed
    return "Declined" if s == :declined

    "Pending"
  end

  def is_transfer?
    amount > 0 && merchant_name.nil?
  end

  def self.total_emburse_card_transaction_volume
    -self.where("amount < 0").completed.sum(:amount)
  end

  def self.total_emburse_card_transaction_count
    self.where("amount < 0").completed.size
  end

end
