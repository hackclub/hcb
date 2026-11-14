# frozen_string_literal: true

class Export
  # One transaction, as every transactions export sees it, whichever engine
  # produced it. The export classes build these from their own records
  # (canonical transactions for the legacy exports, ledger items for the new
  # ones) and hand them to an Export::Format, which decides what each column
  # looks like and what transparency viewers may see. That way those decisions
  # are made once, not once per engine per format.
  #
  # `amount_cents` and `comments` are unredacted: the format applies the
  # transparency rules, since it's the one that knows whether the viewer is
  # entitled to see them.
  Row = Data.define(
    :date,                 # Date
    :memo,                 # String
    :amount_cents,         # Integer, negative for money out
    :account_verification, # true for the micro-deposits that prove ownership of an external account
    :tags,                 # the organization's own tag labels, [String]
    :comments,             # the contents of the comments that aren't admin-only, [String]
    :author,               # User or nil
    :category,             # TransactionCategory or nil
    :merchant,             # Stripe's merchant_data for a card charge, Hash or nil
    :income_type           # "Donation", "Invoice" or "Transfer"
  )

end
