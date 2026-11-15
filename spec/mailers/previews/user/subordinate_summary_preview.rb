# frozen_string_literal: true

class User
  class SubordinateSummaryPreview < ActionMailer::Preview
    def weekly
      manager, subordinates = HackClub::OrgChart.layers.first
      User::SubordinateSummaryMailer.weekly(manager:, subordinates:)
    end

  end

end
