# frozen_string_literal: true

class DocusealController < ActionController::Base
  protect_from_forgery except: :webhook

  def webhook
    ActiveRecord::Base.transaction do
      contract = Contract.find_by(external_id: params[:data][:submission_id])
      return render json: { success: true } unless contract # sometimes contracts are sent using Docuseal that aren't in HCB

      return render json: { success: false } unless request.headers["X-Docuseal-Secret"] == Credentials.fetch(:DOCUSEAL, :WEBHOOK_SECRET)

      if params[:event_type] == "form.completed" && params[:data][:submission][:status] == "completed"
        return render json: { success: true } if contract.signed?

        document = Document.new(
          event: contract.event,
          name: "Fiscal sponsorship contract with #{contract.user.name}"
        )

        response = Faraday.get(params[:data][:documents][0][:url]) do |req|
          req.headers["X-Auth-Token"] = Credentials.fetch(:DOCUSEAL)
        end

        document.file.attach(
          io: StringIO.new(response.body),
          filename: "#{params[:data][:documents][0][:name]}.pdf"
        )

        document.user = User.find_by(email: params[:data][:email]) || contract.event.point_of_contact
        document.save!
        contract.update(document:)
        contract.mark_signed!
      elsif params[:event_type] == "form.declined"
        contract.mark_voided!
      elsif !contract.cosigner_signed?
        # send email about cosigner needing to sign
        ContractMailer.with(contract:).pending_cosigner.deliver_later
      elsif contract.signee_signed? && contract.cosigner_signed?
        # send email about hcb needing to sign
        ContractMailer.with(contract:).pending_hcb.deliver_later
      end
    end
  rescue => e
    Rails.error.report(e)
    return render json: { success: false }
  end

end
