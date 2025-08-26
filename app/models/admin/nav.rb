# frozen_string_literal: true

module Admin
  class Nav
    include Rails.application.routes.url_helpers
    prepend MemoWise


    def sections
      {
        Spending: {
          ACHs: [ach_admin_index_path, AchTransfer.pending.count, %i[]],
          Checks: [increase_checks_admin_index_path, IncreaseCheck.pending.count, %i[]],
          Disbursements: [disbursements_admin_index_path, Disbursement.reviewing.count, %i[]],
          PayPal: [paypal_transfers_admin_index_path, PaypalTransfer.pending.count, %i[]],
          Wires: [wires_admin_index_path, Wire.pending.count, %i[]],
          "Wise transfers": [wise_transfers_admin_index_path, WiseTransfer.pending.count, %i[]],
          Reimbursements: [reimbursements_admin_index_path, Reimbursement::Report.reimbursement_requested.count, %i[]]
        },
        Ledger: {
          Ledger: [ledger_admin_index_path, CanonicalTransaction.not_stripe_top_up.unmapped.count, %i[]],
          "Pending Ledger": [pending_ledger_admin_index_path, CanonicalPendingTransaction.unsettled.count, %i[counter]],
          "Raw Transactions": [raw_transactions_admin_index_path, RawCsvTransaction.unhashed.count, %i[]],
          "Intrafi Transactions": [raw_intrafi_transactions_admin_index_path, RawIntrafiTransaction.count, %i[counter]],
          "HCB codes": [hcb_codes_admin_index_path, 0, %i[counter]],
          "Audits": [admin_ledger_audits_path, Admin::LedgerAudit.pending.count, %i[]],
        },
        "Incoming Money": {
          Donations: [donations_admin_index_path, 0, %i[]],
          "Recurring Donations": [recurring_donations_admin_index_path, 0, %i[]],
          Invoices: [invoices_admin_index_path, 0, %i[]],
          Sponsors: [sponsors_admin_index_path, 0, %i[]]
        },
        Organizations: {
          Organizations: [events_admin_index_path, Event.approved.count, %i[counter]],
          "Google Workspace Requests": [google_workspaces_admin_index_path, GSuite.needs_ops_review.count, %i[]],
          "Account Numbers": [account_numbers_admin_index_path, Column::AccountNumber.count, %i[counter]]
        },
        Payroll: {
          Employees: [employees_admin_index_path, Employee.onboarding.count, %i[]],
          Payments: [employee_payments_admin_index_path, Employee::Payment.paid.count, %i[counter]],
          W9s: [admin_w9s_path, W9.all.count, %i[counter]]
        },
        Misc: {
          "Bank Accounts": [bank_accounts_admin_index_path, BankAccount.failing.count, %i[counter]],
          "HCB Fees": [bank_fees_admin_index_path, BankFee.in_transit_or_pending.count, %i[counter]],
          "Column Statements": [admin_column_statements_path, Column::Statement.count, %i[counter]],
          "Users": [users_admin_index_path, User.count, %i[counter]],
          "Card Designs": [stripe_card_personalization_designs_admin_index_path, StripeCard::PersonalizationDesign.count, %i[counter]],
          "Emails": [emails_admin_index_path, Ahoy::Message.count, %i[counter]],
          "Unknown Merchants": [unknown_merchants_admin_index_path, Rails.cache.fetch("admin_unknown_merchants")&.length || 0, %i[counter]],
          "Referral Programs": [referral_programs_admin_index_path, Referral::Program.count, %i[counter]]
        }
      }
    end

    memo_wise(:sections)

  end
end
