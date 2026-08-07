# frozen_string_literal: true

class EmburseCardRequestsController < ApplicationController
  before_action :set_emburse_card_request, only: [:show]
  skip_before_action :signed_in_user

  def export
    authorize EmburseCardRequest

    emburse_card_requests = EmburseCardRequest.under_review

    attributes = %w{full_name user_email event_name emburse_department_id is_virtual shipping_address_street_one shipping_address_street_two shipping_address_city shipping_address_state shipping_address_zip}

    result = CSV.generate(headers: true) do |csv|
      csv << attributes.map

      emburse_card_requests.each do |cr|
        csv << attributes.map do |attr|
          value = case attr
                  when "user_email"
                    cr.creator.email
                  when "event_name"
                    "##{cr.event.id} #{cr.event.name}"
                  else
                    cr.send(attr)
                  end
          SafeCsv.sanitize(value)
        end
      end
    end

    send_data result, filename: "Pending CRs #{Date.today}.csv"
  end

  # GET /emburse_card_requests
  def index
    @emburse_card_requests = EmburseCardRequest.all.order(created_at: :desc).page params[:page]
    authorize @emburse_card_requests
  end

  # GET /emburse_card_requests/1
  def show
    authorize @emburse_card_request

    @commentable = @emburse_card_request
    @comments = @commentable.comments
    @comment = Comment.new
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_emburse_card_request
    @emburse_card_request = EmburseCardRequest.find(params[:id] || params[:emburse_card_request_id])
    @event = @emburse_card_request.event
  end

end
