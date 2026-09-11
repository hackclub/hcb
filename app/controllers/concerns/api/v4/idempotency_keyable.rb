# frozen_string_literal: true

module Api
  module V4
    # `Idempotency-Key` request header handling, per draft-ietf-httpapi-idempotency-key-header.
    module IdempotencyKeyable
      extend ActiveSupport::Concern

      HEADER = "Idempotency-Key"
      REPLAYED_HEADER = "Idempotent-Replayed"

      included do
        rescue_from Errors::IdempotencyKeyMismatch do |e|
          render json: { error: "idempotency_key_mismatch", messages: [e.message] }, status: :unprocessable_content
        end
      end

      private

      def idempotency_key
        return @idempotency_key if defined?(@idempotency_key)

        key = request.headers[HEADER]&.dup&.force_encoding(Encoding::UTF_8)
        raise ArgumentError, "#{HEADER} must be valid UTF-8" if key && !key.valid_encoding?

        @idempotency_key = key&.strip.presence
      end

      def idempotent_replay!
        response.set_header(REPLAYED_HEADER, "true")
      end

    end
  end
end
