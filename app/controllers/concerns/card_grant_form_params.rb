# frozen_string_literal: true

# Parses the "Send a grant" form for both CardGrantsController (sending a
# grant) and CardGrantTemplatesController (saving the form as a template).
module CardGrantFormParams
  extend ActiveSupport::Concern

  LIST_ATTRIBUTES = %i[merchant_lock category_lock banned_merchants banned_categories].freeze

  included do
    private

    def card_grant_form_params
      permitted = params.require(:card_grant).permit(:email, :amount_cents, :expiration_at, :purpose, :one_time_use, :pre_authorization_required, :invite_message, :instructions, :keyword_lock, *LIST_ATTRIBUTES)

      permitted[:amount_cents] = Monetize.parse(permitted[:amount_cents]).cents if permitted.key?(:amount_cents)
      permitted[:keyword_lock] = permitted[:keyword_lock].to_s.strip.presence if permitted.key?(:keyword_lock)
      LIST_ATTRIBUTES.each do |attribute|
        permitted[attribute] = permitted[attribute].to_s.split(",").map(&:strip).compact_blank if permitted.key?(attribute)
      end

      permitted
    end
  end

end
