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

    @show_flavor_text = Flipper.enabled?(:flavored_receipt_report_2023_05_12, @user)
    @flavor_text = flavor_text.sample if @show_flavor_text

    @show_org = @user.events.size > 1

    mail
  end

  private

  def flavor_text
    [
      # flavor text to put above list of missing receipts
      "You know what happens now!",
      "Don't tell the IRS!",
      "You monster!",
      "Receipts or it didn't happen!",
      "Better upload them or no one will believe you.",
      "Quick! Upload them before they go sour.",
      "Quick! Upload them before they expire.",
      "You're going to get in trouble!",
      "Just a little bit of accounting to go!",
    ]
  end

end
