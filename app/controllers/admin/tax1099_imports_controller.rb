# frozen_string_literal: true

module Admin
  # Migrates W-9s collected through Tax1099 into TaxBandits, one row at a time.
  #
  # The Tax1099 CSV export is parsed entirely in the browser (see the
  # tax1099_import Stimulus controller) and is never uploaded: only the row an
  # admin has actually reviewed and pressed Import on is ever sent here, and only
  # once. The signed W-9 PDF that goes with it is held in memory for TaxBandits
  # to fetch once and is never persisted — see Tax::W9PdfStore.
  class Tax1099ImportsController < Admin::BaseController
    def new
      @federal_tax_classifications = Tax1099ImportService::FEDERAL_TAX_CLASSIFICATIONS
      @tin_types = Tax1099ImportService::TIN_TYPES
      @fields = Tax1099ImportService::FIELDS
    end

    # Answers "who should this form be attached to?" before the row itself is
    # submitted, so the page can ask the admin the question the console script
    # used to ask at the prompt — without having sent a TIN or a PDF yet.
    def legal_entities
      candidates = Tax1099ImportService.legal_entity_candidates(
        email: params[:email].to_s.strip,
        entity_type: Tax1099ImportService.entity_type_for(
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
        pdf_url_builder: ->(token) { taxbandits_w9_pdf_url(token:, format: :pdf) }
      ).run

      render json: {
        status: "imported",
        form_id: result.form.public_id,
        legal_entity: result.legal_entity && { id: result.legal_entity.id, name: result.legal_entity.name },
        needs_manual_review: result.needs_manual_review?
      }
    rescue Tax1099ImportService::DuplicateError => e
      render json: { status: "duplicate", message: e.message, form_id: e.existing_form.public_id }, status: :conflict
    rescue Tax1099ImportService::ValidationError, Tax::W9PdfStore::TooLarge, Tax::W9PdfStore::NotAPdf => e
      render json: { status: "invalid", message: e.message }, status: :unprocessable_entity
    rescue Tax1099ImportService::SubmissionError, Tax::W9PdfStore::CacheUnavailable => e
      render json: { status: "failed", message: e.message }, status: :bad_gateway
    end

    private

    def import_params
      params.permit(*Tax1099ImportService::FIELDS.map { _1[:key] })
    end

    # Blank means "leave this form for manual assignment", which is a real
    # answer rather than a missing one. An id that doesn't resolve is not: it
    # would silently become manual review, so say so instead.
    def selected_legal_entity
      return nil if params[:legal_entity_id].blank?

      LegalEntity.find_by(id: params[:legal_entity_id]) ||
        raise(Tax1099ImportService::ValidationError, "the selected legal entity no longer exists")
    end

  end
end
