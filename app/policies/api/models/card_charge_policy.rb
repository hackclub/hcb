# frozen_string_literal: true

module Api
  module Models
    # Api::Models::CardCharge is an HcbCode under another name, so Pundit
    # doesn't find HcbCodePolicy for it on its own.
    class CardChargePolicy < ApplicationPolicy
      def receiptable_upload?
        HcbCodePolicy.new(user, record).receiptable_upload?
      end

    end
  end
end
