# frozen_string_literal: true

class DocumentsController < ApplicationController
  include SetEvent

  before_action :set_event, only: [:index, :new, :fiscal_sponsorship_letter, :verification_letter], if: -> { params[:id] || params[:event_id] }
  before_action :set_document, except: [:common_index, :index, :new, :create, :fiscal_sponsorship_letter, :verification_letter]
  skip_after_action :verify_authorized, only: [:index]

  def common_index
    authorize @active_documents = Document.common.active
    authorize @archived_documents = Document.common.archived
  end

  def index
    @active_documents = @event.documents.includes(:user).active
    @active_common_documents = Document.common.active
    @archived_documents = @event.documents.includes(:user).archived
    @archived_common_documents = Document.common.archived
  end

  def new
    # documents whose event_id is nil is shared across
    # all events
    @document = Document.new(event: @event || nil)
    authorize @document
  end

  def create
    @document = Document.new(document_params)
    @document.user = current_user
    authorize @document

    if @document.save
      flash[:success] = "Document successfully added"
      redirect_to @document
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    authorize @document
  end

  def edit
    authorize @document
  end

  def update
    @document.assign_attributes(document_params)
    authorize @document

    if @document.save
      flash[:success] = "Document successfully updated"
      redirect_to @document
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle_archive
    authorize @document

    if @document.active?
      @document.mark_archive!(current_user)
      flash[:success] = "Document successfully archived."
    else
      @document.mark_unarchive!
      flash[:success] = "Document successfully unarchived."
    end

    redirect_to @document
  end

  def destroy
    authorize @document

    @document.destroy!

    flash[:success] = "Document successfully deleted."
    redirect_to @document.event || documents_path
  end

  def download
    authorize @document

    redirect_to url_for(@document.file)

    DocumentDownload.from_request(
      request,
      document: @document,
      user: current_user
    ).save!
  end

  def fiscal_sponsorship_letter
    authorize @event, policy_class: DocumentPolicy

    respond_to do |format|
      format.pdf do
        render pdf: "fiscal_sponsorship_letter", page_height: "11in", page_width: "8.5in"
      end

      format.png do
        send_data ::DocumentService::PreviewFiscalSponsorshipLetter.new(event: @event).run, filename: "fiscal_sponsorship_letter.png"
      end
    end
  end

  def verification_letter
    authorize @event, policy_class: DocumentPolicy

    @contract_signers = @event.organizer_positions.where(is_signee: true).includes(:user).map(&:user)

    respond_to do |format|
      format.pdf do
        render pdf: "Verification Letter for #{ActiveStorage::Filename.new(@event.name).sanitized}", page_height: "11in", page_width: "8.5in", template: "documents/verification_letter"
      end

      format.png do
        send_data ::DocumentService::PreviewVerificationLetter.new(event: @event, contract_signers: @contract_signers).run, filename: "verification_letter.png"
      end
    end
  end

  private

  def document_params
    params.require(:document).permit(:event_id, :name, :file)
  end

  def set_document
    @page = params[:page] || 1
    @per = params[:per] || 20

    @document = Document.friendly.find(params[:id] || params[:document_id])
    @downloads = @document.downloads.page(@page).per(@per)
    @event = @document.event
  end

end
