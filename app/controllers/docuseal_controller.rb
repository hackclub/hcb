# frozen_string_literal: true

class DocusealController < ActionController::Base
  protect_from_forgery except: :webhook

  def webhook
    ActiveRecord::Base.transaction do
      contract = OrganizerPosition::Contract.find_by(external_id: params[:data][:submission_id])
      return render json: { success: true } unless contract # sometimes contracts are sent using Docuseal that aren't in HCB

      signee = contract.docuseal_document["submitters"].select { |r| r["role"] == "Cosigner" }
      cosigneer = contract.docuseal_document["submitters"].select { |r| r["role"] == "Contract Signee" }

      if params[:event_type] == "form.completed" && params[:data][:submission][:status] == "completed"
        return render json: { success: true } if contract.signed?

        document = Document.new(
          event: contract.organizer_position_invite.event,
          name: "Fiscal sponsorship contract with #{contract.organizer_position_invite.user.name}"
        )

        response = Faraday.get(params[:data][:documents][0][:url]) do |req|
          req.headers["X-Auth-Token"] = Credentials.fetch(:DOCUSEAL)
        end

        document.file.attach(
          io: StringIO.new(response.body),
          filename: "#{params[:data][:documents][0][:name]}.pdf"
        )

        document.user = User.find_by(email: params[:data][:email]) || contract.organizer_position_invite.event.point_of_contact
        document.save!
        contract.update(document:)
        contract.mark_signed!
      elsif params[:event_type] == "form.declined"
        contract.mark_voided!
      elsif cosigner.present? && cosigner["status"] != "completed"
        # send email about cosigner needing to pay
        OrganizerPosition::ContractsMailer.with(contract:).pending_cosigner.deliver_later
      elsif signee["status"] == "completed" && (cosigner.nil? || cosigner["status"] == "completed")
        # send email about hcb needing to sign
        OrganizerPosition::ContractsMailer.with(contract:).pending_hcb.deliver_later
      end
    end
  rescue => e
    Rails.error.report(e)
    return render json: { success: false }
  end

end
