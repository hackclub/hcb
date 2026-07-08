# frozen_string_literal: true

class TaxbanditsService
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

  def self.get_submission(payee_id:, submission_id:)
    submissions = taxbandits_client.get("WhCertificate/List?PayeeRef=#{payee_id}").body

    submissions["WhcertificateRecords"].find { |s| s["SubmissionId"] == submission_id }
  end

  def self.get_status(payee_id:, submission_id:)
    responses = taxbandits_client.get("WhCertificate/Status?PayeeRef=#{payee_id}").body

    responses["Status"].find { |r| r["SubmissionId"] == submission_id }
  end

  def self.taxbandits_client
    @taxbandits_client || begin
      Faraday.new(url: Rails.env.development? ? "https://testapi.taxbandits.com/v1.7.3/" : "https://api.taxbandits.com/v1.7.3/") do |faraday|
        faraday.response :json
        faraday.response :raise_error
        faraday.adapter Faraday.default_adapter
        faraday.headers["Authorization"] = "Bearer #{taxbandits_access_token}"
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
