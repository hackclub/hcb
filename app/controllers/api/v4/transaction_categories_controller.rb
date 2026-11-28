# frozen_string_literal: true

module Api
  module V4
    # The categories a transaction can have, so clients can show their labels
    # and know which ones a payment transfer accepts.
    class TransactionCategoriesController < ApplicationController
      # The list is the same for everyone.
      skip_after_action :verify_authorized, only: [:index]

      def index
        @categories = TransactionCategory::Definition::ALL.values
        @payment_selectable = TransactionCategory::Definition.payment_selectable
      end

      # Clients need it to choose a payment's category.
      require_oauth2_scope "transfers:write", :index

    end
  end
end
