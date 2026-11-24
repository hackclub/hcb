# frozen_string_literal: true

class ReceiptableMailer < ApplicationMailer
  helper :hcb_code # for attach_receipt_url, so recipients can upload receipts without signing in

  default to: -> { @user.email_address_with_name },
          subject: -> { @subject }

  def receipt_report
    @user = User.find params[:user_id]

    @ledger_item_ids = params[:ledger_item_ids]
    # What the table renders: the card charge for the merchant, the HCB code for
    # the signed upload link, the primary ledger's event (or its card grant's)
    # for the org name.
    @items = Ledger::Item.where(id: @ledger_item_ids).preload(:linked_object, :hcb_code, primary_ledger: [:event, { card_grant: :event }])
    @subject = "[WEEKLY] Missing #{"receipt".pluralize(@ledger_item_ids.size)} on HCB"

    @show_org = @user.events.size > 1

    mail
  end

end
