# frozen_string_literal: true

# == Schema Information
#
# Table name: legal_entity_payout_methods
#
#  id              :bigint           not null, primary key
#  default         :boolean          default(FALSE), not null
#  details_type    :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  details_id      :bigint           not null
#  legal_entity_id :bigint           not null
#
# Indexes
#
#  index_le_payout_methods_one_default_per_entity        (legal_entity_id) UNIQUE WHERE ("default" = true)
#  index_legal_entity_payout_methods_on_details          (details_type,details_id)
#  index_legal_entity_payout_methods_on_legal_entity_id  (legal_entity_id)
#
class LegalEntity
  class PayoutMethod < ApplicationRecord
    ALL_METHODS = [
      LegalEntity::PayoutMethod::AchTransfer,
      LegalEntity::PayoutMethod::Check,
      LegalEntity::PayoutMethod::PaypalTransfer,
      LegalEntity::PayoutMethod::Wire,
      LegalEntity::PayoutMethod::WiseTransfer,
    ].freeze
    UNSUPPORTED_METHODS = {
      LegalEntity::PayoutMethod::PaypalTransfer => {
        status_badge: "Unavailable",
        reason: "Due to integration issues, transfers via PayPal are currently unavailable."
      }
    }.freeze
    SUPPORTED_METHODS = ALL_METHODS - UNSUPPORTED_METHODS.keys

    self.table_name = "legal_entity_payout_methods"

    belongs_to :legal_entity
    belongs_to :details, polymorphic: true

    before_save :unset_other_defaults, if: -> { default? && will_save_change_to_default? }

    # type-specific presentation lives on the detail record
    delegate :kind, :icon, :name, :human_kind, :title_kind, :currency, to: :details

    private

    def unset_other_defaults
      LegalEntity::PayoutMethod
        .where(legal_entity_id:)
        .where.not(id:)
        .update_all(default: false)
    end

  end

end
