# frozen_string_literal: true

# Receives browser CSP violation reports (`report-uri`). Anyone can POST here
# and the payload is forgeable, so every field is treated as untrusted.
class CspViolationReportsController < ActionController::Base
  skip_before_action :verify_authenticity_token

  MAX_BODY_BYTES = Rails.configuration.constants[:csp_violation_report_max_bytes]
  MAX_FIELD_CHARS = 512

  def create
    report = parsed_report
    return head :bad_request if report.blank?

    details = {
      blocked_uri: field(report["blocked-uri"]),
      violated_directive: field(report["violated-directive"]),
      document_uri: field(report["document-uri"]),
      line_number: field(report["line-number"]),
    }.compact

    Rails.logger.warn("[csp-violation] #{details.to_json}")

    head :no_content
  end

  private

  def field(value)
    value.to_s.truncate(MAX_FIELD_CHARS).presence
  end

  # Browsers POST `application/csp-report`, which Rails does not parse into
  # `params`, so read the raw body.
  def parsed_report
    body = request.body.read(MAX_BODY_BYTES + 1).to_s
    return if body.empty? || body.bytesize > MAX_BODY_BYTES

    parsed = JSON.parse(body)
    return unless parsed.is_a?(Hash)
    return parsed unless parsed.key?("csp-report")

    parsed["csp-report"] if parsed["csp-report"].is_a?(Hash)
  rescue JSON::ParserError
    nil
  end

end
