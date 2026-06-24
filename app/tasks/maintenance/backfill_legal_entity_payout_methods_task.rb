# frozen_string_literal: true

module Maintenance
  # Backfills LegalEntity::PayoutMethod records from user PayoutMethod.
  class BackfillLegalEntityPayoutMethodsTask < MaintenanceTasks::Task
    def collection
      User.where.not(payout_method_id: nil)
          .where(id: LegalEntityUser.joins(:legal_entity)
                                    .where(legal_entities: { entity_type: :person })
                                    .select(:user_id))
    end

    def process(user)
      legal_entity = user.legal_entities.find_by(entity_type: :person)
      return unless legal_entity

      details_class = user.payout_method_type.sub(/\AUser::/, "LegalEntity::").safe_constantize
      return unless LegalEntity::PayoutMethod::ALL_METHODS.include?(details_class)

      details = details_class.find_by(id: user.payout_method_id)
      return unless details

      LegalEntity::PayoutMethod.find_or_create_by!(legal_entity:, details:) do |payout_method|
        payout_method.default = true
      end
    end

  end
end
