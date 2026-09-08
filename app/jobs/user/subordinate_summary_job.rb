# frozen_string_literal: true

# I absolutely HATE the term "subordinate". However, I decided to use it in this
# context because it is more descriptive than "direct report". I am open to
# suggestions for a better term.
#
# The org chart itself lives in HackClub::OrgChart.
class User
  class SubordinateSummaryJob < ApplicationJob
    queue_as :low

    def perform
      HackClub::OrgChart.layers.each do |manager, subordinates|
        User::SubordinateSummaryMailer.weekly(manager:, subordinates:).deliver_later
      end
    end

  end

end
