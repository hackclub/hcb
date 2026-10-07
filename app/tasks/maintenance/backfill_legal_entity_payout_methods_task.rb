# frozen_string_literal: true

module Maintenance
  # Backfills LegalEntity::PayoutMethod records from user PayoutMethod.
  class BackfillLegalEntityPayoutMethodsTask < MaintenanceTasks::Task
    def collection
      User.where.not(payout_method_id: nil)
    end

    def process(user)
      legal_entity = user.legal_entities.find_by(entity_type: :person)
      if legal_entity.nil?
        raise ArgumentError, "LE missing for User #{user.id}"
      end

      details_class = LegalEntity::PayoutMethod.details_class_for(
        user.payout_method_type.sub(/\AUser::/, "LegalEntity::")
      )
      return unless details_class

      details = details_class.find_by(id: user.payout_method_id)
      return unless details

      LegalEntity::PayoutMethod.find_or_create_by!(legal_entity:, details:) do |payout_method|
        payout_method.default = true
      end
    end

  end
end
