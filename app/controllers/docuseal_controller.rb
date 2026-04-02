# frozen_string_literal: true

class DocusealController < ActionController::Base
  protect_from_forgery except: :webhook

  def webhook
    return head :unauthorized unless request.headers["X-Docuseal-Secret"] == Credentials.fetch(:DOCUSEAL, :WEBHOOK_SECRET)

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

end
