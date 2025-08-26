# frozen_string_literal: true

module Admin
  class Nav
    include Rails.application.routes.url_helpers
    prepend MemoWise

    Section = Struct.new(:name, :items, keyword_init: true)

    class Item
      attr_reader(:name, :path, :count, :flags)

      def initialize(name:, path:, count:, flags: [])
        @name = name
        @path = path
        @count = count
        @flags = flags
      end

    end

    def initialize(page_title:)
      @page_title = page_title
    end

    def sections
      [
        spending,
        ledger,
        incoming_money,
        organizations,
        payroll,
        misc
      ]
    end

    memo_wise(:sections)

    private

    attr_reader(:page_title)

    def misc
      Section.new(
        name: "Misc",
        items: [
          Item.new(name: "Bank Accounts", path: bank_accounts_admin_index_path, count: BankAccount.failing.count, flags: %i[counter]),
          Item.new(name: "HCB Fees", path: bank_fees_admin_index_path, count: BankFee.in_transit_or_pending.count, flags: %i[counter]),
          Item.new(name: "Column Statements", path: admin_column_statements_path, count: Column::Statement.count, flags: %i[counter]),
          Item.new(name: "Users", path: users_admin_index_path, count: User.count, flags: %i[counter]),
          Item.new(name: "Card Designs", path: stripe_card_personalization_designs_admin_index_path, count: StripeCard::PersonalizationDesign.count, flags: %i[counter]),
          Item.new(name: "Emails", path: emails_admin_index_path, count: Ahoy::Message.count, flags: %i[counter]),
          Item.new(name: "Unknown Merchants", path: unknown_merchants_admin_index_path, count: Rails.cache.fetch("admin_unknown_merchants")&.length || 0, flags: %i[counter]),
          Item.new(name: "Referral Programs", path: referral_programs_admin_index_path, count: Referral::Program.count, flags: %i[counter])
        ]
      )
    end

    def payroll
      Section.new(
        name: "Payroll",
        items: [
          Item.new(name: "Employees", path: employees_admin_index_path, count: Employee.onboarding.count),
          Item.new(name: "Payments", path: employee_payments_admin_index_path, count: Employee::Payment.paid.count, flags: %i[counter]),
          Item.new(name: "W9s", path: admin_w9s_path, count: W9.all.count, flags: %i[counter])
        ]
      )
    end

    def organizations
      Section.new(
        name: "Organizations",
        items: [
          Item.new(name: "Organizations", path: events_admin_index_path, count: Event.approved.count, flags: %i[counter]),
          Item.new(name: "Google Workspace Requests", path: google_workspaces_admin_index_path, count: GSuite.needs_ops_review.count),
          Item.new(name: "Account Numbers", path: account_numbers_admin_index_path, count: Column::AccountNumber.count, flags: %i[counter])
        ]
      )
    end

    def incoming_money
      Section.new(
        name: "Incoming Money",
        items: [
          Item.new(name: "Donations", path: donations_admin_index_path, count: 0),
          Item.new(name: "Recurring Donations", path: recurring_donations_admin_index_path, count: 0),
          Item.new(name: "Invoices", path: invoices_admin_index_path, count: 0),
          Item.new(name: "Sponsors", path: sponsors_admin_index_path, count: 0)
        ]
      )
    end

    def ledger
      Section.new(
        name: "Ledger",
        items: [
          Item.new(name: "Ledger", path: ledger_admin_index_path, count: CanonicalTransaction.not_stripe_top_up.unmapped.count),
          Item.new(name: "Pending Ledger", path: pending_ledger_admin_index_path, count: CanonicalPendingTransaction.unsettled.count, flags: %i[counter]),
          Item.new(name: "Raw Transactions", path: raw_transactions_admin_index_path, count: RawCsvTransaction.unhashed.count),
          Item.new(name: "Intrafi Transactions", path: raw_intrafi_transactions_admin_index_path, count: RawIntrafiTransaction.count, flags: %i[counter]),
          Item.new(name: "HCB codes", path: hcb_codes_admin_index_path, count: 0, flags: %i[counter]),
          Item.new(name: "Audits", path: admin_ledger_audits_path, count: Admin::LedgerAudit.pending.count),
        ]
      )
    end

    def spending
      Section.new(
        name: "Spending",
        items: [
          Item.new(name: "ACHs", path: ach_admin_index_path, count: AchTransfer.pending.count),
          Item.new(name: "Checks", path: increase_checks_admin_index_path, count: IncreaseCheck.pending.count),
          Item.new(name: "Disbursements", path: disbursements_admin_index_path, count: Disbursement.reviewing.count),
          Item.new(name: "PayPal", path: paypal_transfers_admin_index_path, count: PaypalTransfer.pending.count),
          Item.new(name: "Wires", path: wires_admin_index_path, count: Wire.pending.count),
          Item.new(name: "Wise transfers", path: wise_transfers_admin_index_path, count: WiseTransfer.pending.count),
          Item.new(name: "Reimbursements", path: reimbursements_admin_index_path, count: Reimbursement::Report.reimbursement_requested.count)
        ]
      )
    end

  end
end
