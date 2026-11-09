# frozen_string_literal: true

# Book transfers (aka internal account transfers) move funds from one account to
# another in our underlying bank. For example, from FS Main to FS Operating (or
# vice versa).
#
# This concern is used by `BankFee` and `FeeRevenue` to determine the transfer
# direction to/from FS Main and FS Operating. This is necessary because both
# models can result in `amount_cents` inverse of their usual amount. For
# example, a fee credit (`BankFee`) will result in money moving in the opposite
# direction of a traditional bank fee.

# The following assumptions are made for the models that use this concern:
# - The amount to transfer is located in `amount_cents`
# - A positive `amount_cents` indicates a transfer from FS Main to FS Operating
# - A negative `amount_cents` indicates a transfer from FS Operating to FS Main
#
# N.B. This should not be used by Disbursement or any other model that
# represents **multiple** book transfers.
module HasBookTransfer
  extend ActiveSupport::Concern

  def book_transfer_to?(bank_account_sym)
    book_transfer_receiving_account == bank_account_sym
  end

  def book_transfer_originating_account
    book_transfer_accounts[:originator]
  end

  def book_transfer_receiving_account
    book_transfer_accounts[:receiver]
  end

  private

  def book_transfer_accounts
    if amount_cents.negative?
      # For Bank Fees:    This occurs for regular bank fees
      # For Fee Revenues: This occurs when fee credits out weights fiscal sponsorship fees
      { originator: :fs_main, receiver: :fs_operating }
    else
      # For Bank Fees:    This occurs for Fee Credits
      # For Fee Revenues: This occurs for normal fee revenue
      { originator: :fs_operating, receiver: :fs_main }
    end
  end
end
