# frozen_string_literal: true

module OneTimeJobs
  class BackfillCardGrantSettings
    def self.perform
      CardGrant.find_each do |cg|
        default_card_grant_setting = CardGrantSetting.find_by(event_id: cg.id)
        ActiveRecord::Base.transaction do
          card_grant_setting = CardGrantSetting.find_or_create_by!(card_grant_id: cg.id)
          card_grant_setting.update!({
            banned_categories: cg.banned_categories || default_card_grant_setting.banned_categories,
            banned_merchants: cg.banned_merchants || default_card_grant_setting.banned_merchants,
            category_lock: cg.category_lock || default_card_grant_setting.category_lock,
            expiration_preference: default_card_grant_setting.expiration_preference,
            invite_message: default_card_grant_setting.invite_message,
            keyword_lock: cg.keyword_lock || default_card_grant_setting.keyword_lock,
            merchant_lock: cg.merchant_lock || default_card_grant_setting.merchant_lock,
            pre_authorization_required: cg.pre_authorization_required || default_card_grant_setting.pre_authorization_required,
            reimbursement_conversions_enabled: default_card_grant_setting.reimbursement_conversions_enabled
          })
        end
      end
    end

  end
end
