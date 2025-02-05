# frozen_string_literal: true

class User
  class SubordinateSummaryPreview < ActionMailer::Preview
    def weekly
      manager, subordinates = User::SubordinateSummaryJob.org_layers.first
      User::SubordinateSummaryMailer.weekly(manager:, subordinates:)
    end

  end

end
