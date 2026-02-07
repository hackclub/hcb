# frozen_string_literal: true

module OneTimeJobs
  class BackfillTimestampsOnCardGrantSettings < ApplicationJob
    def perform
      CardGrantSetting.find_each do |cg_setting|
        cg_setting.update!(created_at: cg_setting.event.created_at)
        cg_setting.update!(updated_at: cg_setting.event.created_at)
      end
    end

  end

end
