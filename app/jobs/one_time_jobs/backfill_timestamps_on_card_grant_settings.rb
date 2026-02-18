# frozen_string_literal: true

module OneTimeJobs
  class BackfillTimestampsOnCardGrantSettings < ApplicationJob
    def perform
      CardGrantSetting.find_each do |cg_setting|
        cg_setting.update_columns(
          created_at: cg_setting.versions.where(event: "create").first&.created_at || cg_setting.event.created_at,
          updated_at: cg_setting.versions.last&.created_at || cg_setting.event.updated_at
        )
      end
    end

  end

end
