# frozen_string_literal: true

module Maintenance
  # Moves organizations still on the old 1 year default over to the new 90 day default.
  # Settings records are created implicitly the first time an organization touches card
  # grants, so most records sitting at 1 year never reflected a choice by anyone. Records
  # where someone explicitly picked 1 year are left alone, identified by a PaperTrail
  # update touching the preference. Card grants that have already been issued keep the
  # expiration date stored on their own record.
  class BackfillCardGrantSettingExpirationPreferenceTask < MaintenanceTasks::Task
    def collection
      CardGrantSetting.where(expiration_preference: CardGrantSetting.expiration_preferences["1 year"])
                      .where.not(id: explicitly_chosen)
    end

    def process(card_grant_setting)
      card_grant_setting.update!(expiration_preference: "90 days")
    end

    private

    # A record's create version lists every attribute, so only updates indicate a choice.
    # `jsonb_exists` is the function form of the `?` operator, which ActiveRecord would
    # otherwise consume as a bind placeholder.
    def explicitly_chosen
      PaperTrail::Version.where(item_type: "CardGrantSetting", event: "update")
                         .where("jsonb_exists(object_changes, 'expiration_preference')")
                         .select(:item_id)
    end

  end
end
