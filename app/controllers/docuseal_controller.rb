# frozen_string_literal: true

class DocusealController < ActionController::Base
  protect_from_forgery except: :webhook

  before_action :verify_signature

  def webhook
    ActiveRecord::Base.transaction do
      contract = Contract.find_by(external_id: params[:data][:submission_id])
      return head :ok if contract.nil? || contract.signed? # sometimes contracts are sent using Docuseal that aren't in HCB

      if params[:event_type] == "form.completed"
        party = contract.parties.detect { |party| party.docuseal_role == params[:data][:role] }

        if party.present?
          party.with_lock do
            party.mark_signed! unless party.signed?
          end
        else
          Rails.error.unexpected("Unexpected docuseal party #{params[:data][:role]}")
        end
      elsif params[:event_type] == "form.declined"
        contract.mark_voided!
      end
    end

    head :ok
  rescue => e
    Rails.error.report(e)
    head :internal_server_error
  end

  private

  def verify_signature
    unless ActiveSupport::SecurityUtils.secure_compare(
      request.headers["X-Docuseal-Secret"].to_s,
      Credentials.fetch(:DOCUSEAL, :WEBHOOK_SECRET)
    )
      head :unauthorized # calling head/render in a before_action stops the request from reaching the controller action
    end
  end

end
