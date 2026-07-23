# frozen_string_literal: true

class MailboxAddressesController < ApplicationController
  def create
    @mailbox_address = current_user.mailbox_addresses.build

    authorize @mailbox_address

    current_user.mailbox_addresses.previewed.destroy_all

    if @mailbox_address.save
      redirect_to @mailbox_address
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    @mailbox_address = current_user.mailbox_addresses.find(params[:id])

    authorize @mailbox_address
  end

  def activate
    @mailbox_address = current_user.mailbox_addresses.find(params[:id])

    authorize @mailbox_address

    MailboxAddress.transaction do
      current_user.mailbox_addresses.activated.each(&:mark_discarded!)

      @mailbox_address.mark_activated!
    end

    flash[:success] = "Address activated!" unless turbo_frame_request?
    redirect_to @mailbox_address
  rescue ActiveRecord::RecordInvalid
    flash[:error] = "Error activating address" unless turbo_frame_request?
    redirect_to @mailbox_address
  end

end
