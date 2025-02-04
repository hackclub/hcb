# frozen_string_literal: true

class CardGrant
  class ZeroJob < ApplicationJob
    queue_as :low
    def perform

      CardGrant.where.not(status: :active).find_each do |card_grant|
        next if card_grant.last_time_change_to(status: :canceled) > 1.week.ago

        Airbrake.notify("#{card_grant.hashid} is a negative card grant that was canceled more than a week ago") if card_grant.balance.negative?

        next unless card_grant.balance.positive?

        card_grant.zero!
      end

    end

  end

end
