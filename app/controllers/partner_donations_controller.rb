# frozen_string_literal: true

require "csv"

class PartnerDonationsController < ApplicationController
  include SetEvent
  before_action :set_event, only: [:export]

  def show
    @partner_donation = PartnerDonation.find(params[:id])

    authorize @partner_donation

    # Unpaid PDN don't have a transaction associated with it!
    raise ActiveRecord::RecordNotFound if @partner_donation.unpaid?

    @hcb_code = HcbCode.find_or_create_by(hcb_code: @partner_donation.hcb_code)
    redirect_to hcb_code_path(@hcb_code)
  end

  def export
    authorize @event.partner_donations.first

    respond_to do |format|
      format.csv { stream_donations_csv }
      format.json { stream_donations_json }
    end
  end

  private

  def stream_donations_csv
    set_file_headers_csv
    set_streaming_headers

    response.status = 200

    self.response_body = donations_csv
  end

  def stream_donations_json
    set_file_headers_json
    set_streaming_headers

    response.status = 200

    self.response_body = donations_json
  end

  def set_file_headers_csv
    headers["Content-Type"] = "text/csv"
    headers["Content-disposition"] = "attachment; filename=#{export_name("csv")}"
  end

  def set_file_headers_json
    headers["Content-Type"] = "application/json"
    headers["Content-disposition"] = "attachment; filename=#{export_name("json")}"
  end

  def donations_csv
    ::PartnerDonationService::Export::Csv.new(event_id: @event.id).run
  end

  def donations_json
    ::PartnerDonationService::Export::Json.new(event_id: @event.id).run
  end

  def export_name(extension)
    "#{DateTime.now.strftime("%Y-%m-%d_%H:%M:%S")}_#{@event.name.to_param}_donations.#{extension}"
  end

end
