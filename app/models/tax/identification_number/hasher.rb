# frozen_string_literal: true

module Tax
  class IdentificationNumber
    class Hasher
      # Should be in the format XXX-XX-XXXX for SSNs and XX-XXXXXXX for EINs
      # FTINs should be in whatever format is standard for the country
      def self.hash_tin(tin)
        if Rails.env.production?
          # AWS KMS
        else
          Digest::SHA256.hexdigest(tin.to_s)
        end
      end

    end

  end
end
