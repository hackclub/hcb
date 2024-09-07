# frozen_string_literal: true

module SearchService
  module Shared
    def shorthands
      {
        "org"          => "organization",
        "organisation" => "organization",
        "txn"          => "transaction"
      }
    end

    def subtype_shorthands
      {
        "ach"      => "ach_transfer",
        "transfer" => "account_transfer",
        "card"     => "card_charge",
        "check"    => "mailed_check",
        "fee"      => "fiscal_sponsorship_fee"
      }
    end

    def types
      {
        "organization"  => {
          "children"   => %w[
            user
            card
            transaction
            reimbursement
          ],
          "subtypes"   => [],
          "properties" => [
            "date"
          ]
        },
        "user"          => {
          "children"   => %w[
            organization
            card
            transaction
            reimbursement
          ],
          "subtypes"   => [],
          "properties" => []
        },
        "card"          => {
          "children"   => [
            "transaction"
          ],
          "subtypes"   => [],
          "properties" => [
            "date"
          ]
        },
        "transaction"   => {
          "children"   => [],
          "properties" => %w[
            date
            amount
          ],
          "subtypes"   => {
            "ach_transfer"           => ->(t) { t.local_hcb_code.ach_transfer? },
            "mailed_check"           => ->(t) { t.local_hcb_code.check? || t.local_hcb_code.increase_check? },
            "account_transfer"       => ->(t) { t.local_hcb_code.disbursement? },
            "card_charge"            => ->(t) { t.raw_stripe_transaction },
            "check_deposit"          => ->(t) { t.local_hcb_code.check_deposit? },
            "donation"               => ->(t) { t.local_hcb_code.donation? },
            "invoice"                => ->(t) { t.local_hcb_code.invoice? },
            "refund"                 => ->(t) { t.local_hcb_code.stripe_refund? },
            "fiscal_sponsorship_fee" => ->(t) { t.local_hcb_code.fee_revenue? || t.fee_payment? }
          },
        },
        "reimbursement" => {
          "children"   => [],
          "properties" => %w[
            date
          ],
        }
      }
    end

    def convert_to_float(input)
      match = input.match(/\d+(\.\d{1,2})?/)
      if match
        result = match[0].to_f.round(2)
        return result
      else
        return nil
      end
    end
  end
end
