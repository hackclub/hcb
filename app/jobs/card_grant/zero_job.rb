# frozen_string_literal: true

class CardGrant
  class ZeroJob < ApplicationJob
    queue_as :low
    def perform

      CardGrant.where.not(status: :active).find_each do |card_grant|
        next if card_grant.balance.zero?

        card_grant.zero!
      end

    end

  end

end
