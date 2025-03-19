# frozen_string_literal: true

# == Schema Information
#
# Table name: canonical_event_mappings
#
#  id                       :bigint           not null, primary key
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  canonical_transaction_id :bigint           not null
#  event_id                 :bigint           not null
#  subledger_id             :bigint
#  user_id                  :bigint
#
# Indexes
#
#  index_canonical_event_mappings_on_canonical_transaction_id  (canonical_transaction_id)
#  index_canonical_event_mappings_on_event_id                  (event_id)
#  index_canonical_event_mappings_on_subledger_id              (subledger_id)
#  index_canonical_event_mappings_on_user_id                   (user_id)
#  index_cem_event_id_canonical_transaction_id_uniqueness      (event_id,canonical_transaction_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (canonical_transaction_id => canonical_transactions.id)
#  fk_rails_...  (event_id => events.id)
#
class CanonicalEventMapping < ApplicationRecord
  include HasBalanceMonitoring

  broadcasts_refreshes_to ->(mapping) { [mapping.event, :transactions] }

  belongs_to :canonical_transaction
  belongs_to :event
  belongs_to :subledger, optional: true
  belongs_to :user, optional: true

  has_one :fee, dependent: :destroy
  validates_associated :fee

  scope :on_main_ledger, -> { where(subledger_id: nil) }

  after_create { canonical_transaction.write_hcb_code }
  after_create if: -> { fee.nil? } do
    FeeEngine::Create.new(canonical_event_mapping: self).run
  end

  scope :missing_fee, -> { includes(:fee).where(fee: { canonical_event_mapping_id: nil }) }
  scope :mapped_by_human, -> { where("user_id is not null") }

  validate :transaction_belongs_to_correct_increase_account

  private

  def transaction_belongs_to_correct_increase_account
    return if canonical_transaction.transaction_source_type != RawIncreaseTransaction.name
    return if event.id == EventMappingEngine::EventIds::NOEVENT # hacky - allow all transactions to be mapped to 999 (NoEvent)
    return if canonical_transaction.raw_increase_transaction&.category == "interest_payment"

    if canonical_transaction.raw_increase_transaction.increase_account_id != event.increase_account_id
      errors.add(:base, "This transaction can't be mapped to \"#{event.name}\" because they belong to different Increase accounts.")
    end
  end

end
