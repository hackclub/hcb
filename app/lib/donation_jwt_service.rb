# frozen_string_literal: true

require "openssl"
require "json"
require "base64"

# Service for generating and verifying JWT tokens for donation details
# Used when redirecting donors to external URLs with donation information
class DonationJwtService
  ALGORITHM = "HS256"

  # Generate a JWT token with donation details
  # @param donation [Donation] The donation object
  # @return [String] The JWT token
  def self.generate_token(donation)
    header = {
      alg: ALGORITHM,
      typ: "JWT"
    }

    payload = {
      id: donation.public_id,
      name: donation.name(show_anonymous: false),
      amount: donation.amount,
      iat: Time.now.to_i,
      exp: (Time.now + 1.hour).to_i
    }

    encoded_header = base64_url_encode(header.to_json)
    encoded_payload = base64_url_encode(payload.to_json)
    signature = sign("#{encoded_header}.#{encoded_payload}")

    "#{encoded_header}.#{encoded_payload}.#{signature}"
  end

  # Verify and decode a JWT token
  # @param token [String] The JWT token
  # @return [Hash, nil] The decoded payload or nil if invalid
  def self.verify_token(token)
    parts = token.split(".")
    return nil if parts.length != 3

    encoded_header, encoded_payload, signature = parts

    # Verify signature
    expected_signature = sign("#{encoded_header}.#{encoded_payload}")
    return nil unless secure_compare(signature, expected_signature)

    # Decode and parse payload
    payload = JSON.parse(Base64.urlsafe_decode64(encoded_payload))

    # Check expiration
    return nil if payload["exp"] && payload["exp"] < Time.now.to_i

    payload
  rescue StandardError
    nil
  end

  private_class_method def self.sign(data)
    hmac = OpenSSL::HMAC.digest(OpenSSL::Digest.new("sha256"), secret_key, data)
    base64_url_encode(hmac)
  end

  private_class_method def self.base64_url_encode(data)
    Base64.urlsafe_encode64(data, padding: false)
  end

  private_class_method def self.secret_key
    # Use Rails secret_key_base for signing
    Rails.application.secret_key_base
  end

  # Constant-time string comparison to prevent timing attacks
  private_class_method def self.secure_compare(a, b)
    ActiveSupport::SecurityUtils.secure_compare(a, b)
  end
end
