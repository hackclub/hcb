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
#  index_legal_entity_payout_methods_on_details          (details_type,details_id) UNIQUE
#  index_legal_entity_payout_methods_on_legal_entity_id  (legal_entity_id)
#
class LegalEntity
  class PayoutMethod < ApplicationRecord
    has_paper_trail

    ALL_METHODS = [
      LegalEntity::PayoutMethod::AchTransfer,
      LegalEntity::PayoutMethod::Check,
      LegalEntity::PayoutMethod::Wire,
      LegalEntity::PayoutMethod::WiseTransfer,
    ].freeze
    UNSUPPORTED_METHODS = {
      # If a PayoutMethod is deprecated, add a key with the PayoutMethod's
      # class with the value being a hash with status_badge(string)
      # and reason(string)
    }.freeze
    SUPPORTED_METHODS = ALL_METHODS - UNSUPPORTED_METHODS.keys

    self.table_name = "legal_entity_payout_methods"

    belongs_to :legal_entity
    belongs_to :details, polymorphic: true, dependent: :destroy

    before_save :unset_other_defaults, if: -> { default? && will_save_change_to_default? }

    validate :details_must_be_supported

    # type-specific presentation lives on the detail record
    delegate :kind, :icon, :name, :human_kind, :title_kind, :currency, to: :details

    def unsupported?
      UNSUPPORTED_METHODS.key?(details.class)
    end

    def unsupported_details
      UNSUPPORTED_METHODS[details.class]
    end

    private

    def details_must_be_supported
      if unsupported?
        errors.add(:base, "#{unsupported_details[:reason]} Please choose another method.")
      end
    end

    def unset_other_defaults
      LegalEntity::PayoutMethod
        .where(legal_entity_id:)
        .excluding(self)
        .update_all(default: false)
    end

  end

end
