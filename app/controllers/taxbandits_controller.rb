# frozen_string_literal: true

class TaxbanditsController < ActionController::Base
  TAXBANDITS_IP = "34.194.128.121"

  protect_from_forgery except: :webhook

  before_action :verify_ip
  before_action :verify_signature

  # TaxBandits fetches PdfUrl from their own processing infrastructure, which is
  # not the host their webhooks come from and whose egress addresses they do not
  # publish, so neither of the checks above can apply here. What authorizes the
  # read instead is the URL itself: a 256-bit single-use token that only ever
  # existed inside the WhCertificate/Create call HCB just made. See
  # Tax::W9PdfStore for the guarantees that rest on that.
  skip_before_action :verify_ip, :verify_signature, only: :w9_pdf

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

  # Serves a staged W-9 PDF to TaxBandits exactly once. The token is passed in
  # the query string rather than the path so that Rails' parameter filtering
  # (:token is already in config.filter_parameters) redacts it from the request
  # log — a path segment would be logged verbatim.
  def w9_pdf
    pdf = Tax::W9PdfStore.claim(params[:token])

    # An expired token, an already-spent one, and one that never existed are
    # deliberately indistinguishable.
    return head :not_found if pdf.nil?

    # Nothing may keep a copy: not the browser, not a proxy, not a CDN.
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, private"
    response.headers["Pragma"] = "no-cache"

    send_data pdf, type: Tax::W9PdfStore::CONTENT_TYPE, disposition: "inline", filename: "w9.pdf"
  end

  private

  # TaxBandits is inconsistent with their capitalization
  def normalize_form_name(str)
    str.sub(/\AFORM/i, "Form")
  end

  def verify_ip
    if request.remote_ip != TAXBANDITS_IP
      head :unauthorized
    end
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
