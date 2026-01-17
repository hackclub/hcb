# frozen_string_literal: true

class DocusealController < ActionController::Base
  protect_from_forgery except: :webhook

  def webhook
    ActiveRecord::Base.transaction do
      return render json: { success: false } unless request.headers["X-Docuseal-Secret"] == Credentials.fetch(:DOCUSEAL, :WEBHOOK_SECRET)

      contract = Contract.find_by(external_id: params[:data][:submission_id])
      return render json: { success: true } if contract.nil? || contract.signed? # sometimes contracts are sent using Docuseal that aren't in HCB

      if params[:event_type] == "form.completed"
        party = contract.parties.detect { |party| party.docuseal_role == params[:data][:role] }
        if party.present?
          party.mark_signed!
        else
          Rails.error.unexpected("Unexpected docuseal party #{params[:data][:role]}")
        end
      elsif params[:event_type] == "form.declined"
        contract.mark_voided!
      end
    end

    return render json: { success: true }
  rescue => e
    Rails.error.report(e)
    return render json: { success: false }
  end

end
