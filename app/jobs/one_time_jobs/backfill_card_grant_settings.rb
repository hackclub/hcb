# frozen_string_literal: true

module OneTimeJobs
  class BackfillCardGrantSettings
    def self.perform
      CardGrant.find_each do |cg|
        default_cg_setting = CardGrantSetting.where(event_id: cg.id, card_grant_id: nil).first
        ActiveRecord::Base.transaction do
          cg_setting = CardGrantSetting.find_or_create_by!(card_grant_id: cg.id)
          cg_setting.update!(
            {
              banned_categories: (cg.banned_categories + (default_cg_setting&.banned_categories || [])).uniq,
              banned_merchants: (cg.banned_merchants + (default_cg_setting&.banned_merchants || [])).uniq,
              category_lock: (cg.category_lock + (default_cg_setting&.category_lock || [])).uniq,
              expiration_preference: default_cg_setting&.expiration_preference,
              invite_message: default_cg_setting&.invite_message,
              keyword_lock: cg.keyword_lock || default_cg_setting&.keyword_lock,
              merchant_lock: (cg.merchant_lock + (default_cg_setting&.merchant_lock || [])).uniq,
              pre_authorization_required: [cg.pre_authorization_required, default_cg_setting&.pre_authorization_required].first(&:present?),
              reimbursement_conversions_enabled: default_cg_setting&.reimbursement_conversions_enabled
            }
          )
        end
      end
    end

  end
end
