# frozen_string_literal: true

class TaxbanditsController < ActionController::Base
  protect_from_forgery except: :webhook

  before_action :verify_signature

  def webhook
    form_type = params["FormType"]
    return if form_type.nil?

    submission_id = params[normalize_form_name(form_type)]&.[]("SubmissionId")
    return if submission_id.nil?

    # TaxBandits does send us the status in the webhook itself,
    # but it doesn't seem to support the full set of statuses that
    # the API does, so we just use it as a notification to fetch from API
    # https://developer.taxbandits.com/docs/Webhooks/WhCertificateStatusChange
    form = Tax::Form.find_by(external_service: :taxbandits, external_id: submission_id)
    form&.sync_with_taxbandits

    head :ok
  end

  private
  
  # TaxBandits is inconsistent with their capitalization
  def normalize_form_name(str)
    str.sub(/\AFORM/i, "Form")
  end

  def verify_signature
    time_stamp = request.headers["TimeStamp"]
    client_id = Credentials.fetch(:TAXBANDITS, :CLIENT_ID)
    client_secret = Credentials.fetch(:TAXBANDITS, :CLIENT_SECRET)

    message = "#{client_id}\n#{time_stamp}"
    key = client_secret.encode("utf-8")
    hmac = OpenSSL::HMAC.new(key, "sha256")
    hmac.update(message)
    signature = Base64.strict_encode64(hmac.digest)

    unless ActiveSupport::SecurityUtils.secure_compare(signature, request.headers["Signature"])
      head :unauthorized # calling head/render in a before_action stops the request from reaching the controller action
    end
  end

end
