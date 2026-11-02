# frozen_string_literal: true

module Tax
  class IdentificationNumber
    class Hasher
      MAC_ALGORITHM = "HMAC_SHA_256"

      # The TIN spaces the IRS issues from. SSN and ITIN share one space (an ITIN
      # can never collide with an SSN), so both normalize to :individual. An EIN is
      # drawn from a separate space and can legitimately share its nine digits with
      # someone's SSN, so it must be namespaced apart. A foreign TIN has no
      # relationship to either and is namespaced by its issuing country.
      INDIVIDUAL = :individual
      ENTITY = :entity
      FOREIGN = :foreign
      TIN_TYPES = [INDIVIDUAL, ENTITY, FOREIGN].freeze

      class HashingError < StandardError; end

      # The same taxpayer has to fingerprint identically no matter how their TIN
      # reached us: imported from a TaxBandits W-9, or keyed in by an organizer on
      # a contractor's behalf. So the namespace describes the TIN, never the source.
      def self.tin_type_for(entity_type:, foreign: false)
        return FOREIGN if foreign

        entity_type.to_s == "person" ? INDIVIDUAL : ENTITY
      end

      # Fingerprints a TIN so that two records belonging to the same taxpayer
      # produce the same value, without ever storing the TIN itself.
      #
      # tin_type and country are required: they namespace the fingerprint, and a
      # caller that forgets them would silently merge an EIN with an identical SSN.
      def self.hash_tin(tin, tin_type:, country:)
        normalized = normalize(tin)
        return nil if normalized.blank?

        fingerprint(message_for(normalized, tin_type:, country:))
      end

      # "US:INDIVIDUAL:123456789"
      def self.message_for(normalized, tin_type:, country:)
        raise HashingError, "unknown TIN type" unless TIN_TYPES.include?(tin_type)
        raise HashingError, "missing country" if country.blank?

        [country.to_s.upcase, tin_type.to_s.upcase, normalized].join(":")
      end
      private_class_method :message_for

      def self.normalize(tin)
        tin.to_s.strip.gsub(/[^0-9A-Za-z]/, "").upcase.presence
      end
      private_class_method :normalize

      def self.fingerprint(message)
        digest = Base64.strict_encode64(mac(message))

        kms_key_id.present? ? digest : "DEV_#{digest}"
      rescue HashingError
        # Already free of the TIN, and it names the actual problem (a misconfigured
        # KMS reads very differently from a malformed TIN). Let it through as-is.
        raise
      rescue
        # The TIN is in scope here, so the original error's message, backtrace, and
        # cause could all carry it. cause: nil severs the chain so nothing sensitive
        # can reach Rails logs or AppSignal.
        raise HashingError, "failed to fingerprint TIN", cause: nil
      end
      private_class_method :fingerprint

      def self.mac(message)
        if kms_key_id.present?
          # Pre-hash so the TIN itself never leaves this process: HMAC(k, SHA256(m))
          # is still a keyed PRF, so AWS gets a digest rather than an SSN.
          kms_client.generate_mac(
            key_id: kms_key_id,
            message: Digest::SHA256.digest(message),
            mac_algorithm: MAC_ALGORITHM
          ).mac
        elsif Rails.env.local?
          # Development and test only, and still keyed, so the fingerprint of a
          # made-up TIN behaves like the real thing.
          OpenSSL::HMAC.digest("SHA256", dev_key, message)
        else
          # Every deployed environment (production, staging) reaches real TINs, so
          # none of them may fall back to a key that lives in the repo.
          raise HashingError, "AWS KMS is not configured; refusing to fingerprint a TIN"
        end
      end
      private_class_method :mac

      def self.kms_key_id = Credentials.fetch(:AWS_KMS, :TIN_KEY_ID)
      private_class_method :kms_key_id

      def self.dev_key = Credentials.fetch(:TIN_HMAC_DEV_KEY, fallback: "development-key")
      private_class_method :dev_key

      def self.kms_client
        @kms_client ||= Aws::KMS::Client.new(
          region: Credentials.fetch(:AWS_KMS, :REGION),
          access_key_id: Credentials.fetch(:AWS_KMS, :ACCESS_KEY_ID),
          secret_access_key: Credentials.fetch(:AWS_KMS, :SECRET_ACCESS_KEY),
          http_open_timeout: 5,
          http_read_timeout: 10
        )
      end
      private_class_method :kms_client

    end

  end
end
