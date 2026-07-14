# frozen_string_literal: true

module Tax
  class IdentificationNumber
    class Hasher
      MAC_ALGORITHM = "HMAC_SHA_256"

      class HashingError < StandardError; end

      def self.hash_tin(tin, tin_type: nil, country: nil)
        normalized = normalize(tin)
        return nil if normalized.blank?

        digest = Base64.strict_encode64(mac(message_for(normalized, tin_type:, country:)))

        hash = kms_key_id.present? ? digest : "DEV_#{digest}"

        raise HashingError, "TIN matches hash" if hash == tin

        hash
      rescue
        # cause: nil severs the original exception, whose message/backtrace could
        # carry the TIN, so nothing sensitive can be logged as this error bubbles up.
        raise HashingError, "failed to fingerprint TIN", cause: nil
      end

      # "US:SSN:123456789" - namespaced so a US SSN and a foreign TIN with the
      # same digits cannot collide into one taxpayer.
      def self.message_for(normalized, tin_type:, country:)
        [(country.presence || "US").upcase,
         (tin_type.presence || "TIN").upcase,
         normalized].join(":")
      end
      private_class_method :message_for

      def self.normalize(tin)
        tin.strip.to_s.gsub(/[^0-9A-Za-z]/, "").upcase.presence
      end
      private_class_method :normalize

      def self.mac(message)
        if kms_key_id.present?
          kms_client.generate_mac(key_id: kms_key_id, message:, mac_algorithm: MAC_ALGORITHM).mac
        elsif Rails.env.production?
          raise HashingError, "AWS KMS is not configured; refusing to fingerprint a TIN"
        else
          OpenSSL::HMAC.digest("SHA256", dev_key, message)
        end
      end
      private_class_method :mac

      def self.kms_key_id = Credentials.fetch(:AWS_KMS, :TIN_KEY_ID)
      private_class_method :kms_key_id

      def self.dev_key = Credentials.fetch(:TIN_HMAC_DEV_KEY, fallback: "development-key").presence
      private_class_method :dev_key

      def self.kms_client
        @kms_client ||= Aws::KMS::Client.new(
          region: Credentials.fetch(:AWS_KMS, :REGION),
          access_key_id: Credentials.fetch(:AWS_KMS, :ACCESS_KEY_ID),
          secret_access_key: Credentials.fetch(:AWS_KMS, :SECRET_ACCESS_KEY)
        )
      end
      private_class_method :kms_client

    end

  end
end
