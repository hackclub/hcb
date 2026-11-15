# frozen_string_literal: true

module Admin
  # Migrates W-9s and W-8s collected through Tax1099 into TaxBandits, one row at
  # a time.
  #
  # The Tax1099 CSV export is parsed entirely in the browser (see the
  # tax1099_import Stimulus controller) and is never uploaded: only the row an
  # admin has actually reviewed and pressed Import on is ever sent here, and only
  # once. The signed form PDF that goes with it is held in memory for TaxBandits
  # to fetch once and is never persisted — see Tax::W9PdfStore.
  class Tax1099ImportsController < Admin::BaseController
    # The legal entity picker's value for "create a new business legal entity".
    NEW_LEGAL_ENTITY = "new"

    def new
      @federal_tax_classifications = Tax1099ImportService::FEDERAL_TAX_CLASSIFICATIONS
      @tin_types = Tax1099ImportService::TIN_TYPES
      @form_types = Tax1099ImportService::FORM_TYPES
      @ch3_statuses = Tax1099ImportService::CH3_STATUSES
      @fields = Tax1099ImportService::FIELDS
      @imported_row_keys = Tax1099ImportService.imported_row_keys
    end

    # Answers "who should this form be attached to?" before the row itself is
    # submitted, so the page can ask the admin the question the console script
    # used to ask at the prompt — without having sent a TIN or a PDF yet.
    def legal_entities
      candidates = Tax1099ImportService.legal_entity_candidates(
        email: params[:email].to_s.strip,
        entity_type: Tax1099ImportService.entity_type_for(
          form_type: params[:form_type].to_s,
          tin_type: params[:tin_type].to_s,
          federal_tax_classification: params[:federal_tax_classification].to_s
        )
      )

      render json: {
        legal_entities: candidates.map { { id: _1.id, name: _1.name, entity_type: _1.entity_type } }
      }
    end

    def create
      result = Tax1099ImportService.new(
        data: import_params.to_h,
        pdf: params[:pdf],
        legal_entity: selected_legal_entity,
        new_legal_entity: params[:legal_entity_id] == NEW_LEGAL_ENTITY,
        pdf_url_builder: ->(token) { taxbandits_pdf_url(token) }
      ).run

      render json: {
        status: "imported",
        form_id: result.form.public_id,
        legal_entity: { id: result.legal_entity.id, name: result.legal_entity.name }
      }
    rescue Tax1099ImportService::UncertainSubmissionError => e
      # Neither a success nor a clean failure: the form was kept, and the row
      # must not be retried as-is. See Tax1099ImportService#run.
      render json: { status: "uncertain", message: e.message, form_id: e.form.public_id }, status: :accepted
    rescue Tax1099ImportService::DuplicateError => e
      render json: { status: "duplicate", message: e.message, form_id: e.existing_form.public_id }, status: :conflict
    rescue Tax1099ImportService::ValidationError, Tax::W9PdfStore::TooLarge, Tax::W9PdfStore::NotAPdf => e
      render json: { status: "invalid", message: e.message }, status: :unprocessable_entity
    rescue Tax1099ImportService::SubmissionError, Tax::W9PdfStore::CacheUnavailable => e
      render json: { status: "failed", message: e.message }, status: :bad_gateway
    rescue => e
      # Answered as JSON rather than left to become a 500 page, so the page can
      # tell this apart from a request that never got an answer. Only the class
      # is shown: the message could carry the TIN. That nothing was submitted
      # is guaranteed by Tax1099ImportService#run, which lets no other error
      # escape once a form exists.
      Rails.error.report(e, handled: true)
      render json: {
        status: "failed",
        message: "Something went wrong before anything was submitted to TaxBandits (#{e.class}). " \
                 "Nothing was imported; you can try again."
      }, status: :internal_server_error
    end

    private

    def import_params
      params.permit(*Tax1099ImportService::FIELDS.map { _1[:key] })
    end

    # Blank (no pick) and NEW_LEGAL_ENTITY are left for the service to judge.
    # An id that doesn't resolve is an error in its own right: it must not be
    # quietly treated as no pick.
    def selected_legal_entity
      return nil if params[:legal_entity_id].blank? || params[:legal_entity_id] == NEW_LEGAL_ENTITY

      LegalEntity.find_by(id: params[:legal_entity_id]) ||
        raise(Tax1099ImportService::ValidationError, "the selected legal entity no longer exists")
    end

    # TaxBandits fetches this URL from the outside, so in development it has to
    # use TEST_URL_HOST (e.g. an ngrok tunnel) rather than the request's host,
    # which is usually localhost:3000. The request-free route helpers use
    # default_url_options, which development sets from TEST_URL_HOST.
    #
    # The URL must end in ".pdf" for TaxBandits, but the token has to stay in the
    # query string (see TaxbanditsController#w9_pdf), so a trailing, ignored
    # filename parameter supplies the extension. It's appended by hand because
    # url_for sorts query parameters, which would put it before the token.
    def taxbandits_pdf_url(token)
      url = if Rails.env.development?
              Rails.application.routes.url_helpers.taxbandits_w9_pdf_url(token:, format: :pdf)
            else
              taxbandits_w9_pdf_url(token:, format: :pdf)
            end

      "#{url}&filename=w9.pdf"
    end

  end
end
