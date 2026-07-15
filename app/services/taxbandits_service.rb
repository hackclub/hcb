# frozen_string_literal: true

class TaxbanditsService
  # TaxBandits' response keys for the GET endpoint the form data under a slightly different
  # casing than the "FormType" value itself (e.g. "FormW8BEN" -> "FormW8Ben").
  TAXBANDITS_FORM_DATA_KEYS = {
    "FormW9"     => "FormW9",
    "FormW8BEN"  => "FormW8Ben",
    "FormW8BENE" => "FormW8BenE",
    "FormW8ECI"  => "FormW8ECI",
    "FormW8IMY"  => "FormW8IMY",
    "FormW8EXP"  => "FormW8EXP"
  }.freeze

  def self.create_whcertificate(id:, name:)
    response = taxbandits_client.post("WhCertificate/RequestByUrl") do |req|
      req.body = {
        "Recipient" => {
          "PayeeRef"      => id,
          "Name"          => name,
          "IsTINMatching" => true
        },
        "CustomizationId": Credentials.fetch(:TAXBANDITS, :CUSTOMIZATION_ID)
      }.to_json
    end

    response.body
  end

  # Returns the full, unmasked TIN. Only Tax::Form#import_taxbandits_data may call
  # this, and only to fingerprint the TIN; nothing else in HCB may touch it.
  def self.get_submission(payee_ref)
    Rails.logger.info("TaxBandits: get_submission for PayeeRef=#{payee_ref} by current_user_id=#{Current.user&.id || "nil"}")
    taxbandits_client.get("WhCertificate/Get?PayeeRef=#{payee_ref}").body
  end

  # Returns the TIN already masked by TaxBandits.
  def self.get_list_entry(payee_ref)
    Rails.logger.info("TaxBandits: get_list_entry for PayeeRef=#{payee_ref} by current_user_id=#{Current.user&.id || "nil"}")
    submissions = taxbandits_client.get("WhCertificate/List?PayeeRef=#{payee_ref}").body

    submissions["WhcertificateRecords"]&.first
  end

  def self.get_status(payee_ref)
    statuses = taxbandits_client.get("WhCertificate/Status?PayeeRef=#{payee_ref}").body

    statuses["Status"]&.first
  end

  def self.taxbandits_client
    @taxbandits_client || begin
      Faraday.new(url: Rails.env.development? ? "https://testapi.taxbandits.com/v1.7.3/" : "https://api.taxbandits.com/v1.7.3/") do |faraday|
        faraday.response :json
        faraday.response :raise_error
        faraday.adapter Faraday.default_adapter
        faraday.headers["Authorization"] = "Bearer #{taxbandits_access_token}"
        faraday.headers["Referer"] = Credentials.fetch(:TAXBANDITS, :DOMAIN_ID)
        faraday.headers["Content-Type"] = "application/json"
      end
    end
  end

  def self.taxbandits_access_token
    Rails.cache.fetch("taxbandits_access_token", expires_in: 50.minutes) do
      payload = {
        iss: Credentials.fetch(:TAXBANDITS, :CLIENT_ID),
        sub: Credentials.fetch(:TAXBANDITS, :CLIENT_ID),
        aud: Credentials.fetch(:TAXBANDITS, :USER_TOKEN),
        iat: Time.now.to_i
      }

      signature = JWT.encode(payload, Credentials.fetch(:TAXBANDITS, :CLIENT_SECRET), "HS256")

      oauth_response = Faraday.new(url: Rails.env.development? ? "https://testoauth.expressauth.net" : "https://oauth.expressauth.net") do |conn|
        conn.response :json
        conn.response :raise_error
        conn.headers["Authentication"] = signature
        conn.adapter Faraday.default_adapter
      end.get("/v2/tbsauth")

      token = oauth_response.body["AccessToken"]
      raise "TaxBandits auth failed: no AccessToken in response" if token.blank?

      token
    end
  end

end
