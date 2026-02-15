# frozen_string_literal: true

module Admin
  class Nav
    include Rails.application.routes.url_helpers
    prepend MemoWise

    class Section
      prepend MemoWise
      attr_reader(:name, :items)

      def initialize(name:, items:)
        @name = name
        @items = items
      end

      def active?
        items.any?(&:active?)
      end

      memo_wise(:active?)

      def task_sum
        items.sum { |item| item.task_count? ? item.count : 0 }
      end

      memo_wise(:task_sum)

      def counter_sum
        items.sum { |item| item.record_count? ? item.count : 0 }
      end

      memo_wise(:counter_sum)

    end

    class Item
      attr_reader(:name, :path, :count)

      def initialize(name:, path:, count:, count_type: :tasks, active: false)
        @name = name
        @path = path
        @count = count
        @count_type = count_type
        @active = active

        unless [:tasks, :records].include?(count_type)
          raise ArgumentError, "invalid count_type: #{count_type.inspect}"
        end
      end

      def active?
        @active
      end

      def record_count?
        @count_type == :records
      end

      def task_count?
        @count_type == :tasks
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

    def active_section
      sections.find(&:active?)
    end

    memo_wise(:active_section)

    private

    attr_reader(:page_title)

    def normalize_string(str)
      str.to_s.downcase.gsub(" ", "")
    end

    def normalized_page_title
      @normalized_page_title ||= normalize_string(page_title)
    end

    def make_item(name:, **properties)
      Item.new(
        name:,
        **properties,
        active: normalize_string(name) == normalized_page_title
      )
    end

    def misc
      Section.new(
        name: "Misc",
        items: [
          make_item(
            name: "Bank Accounts",
            path: bank_accounts_admin_index_path,
            count: BankAccount.failing.count,
            count_type: :records
          ),
          make_item(
            name: "HCB Fees",
            path: bank_fees_admin_index_path,
            count: BankFee.in_transit_or_pending.count,
            count_type: :records
          ),
          make_item(
            name: "Fee Revenues",
            path: fee_revenues_admin_index_path,
            count: FeeRevenue.count,
            count_type: :records
          ),
          make_item(
            name: "Column Statements",
            path: admin_column_statements_path,
            count: Column::Statement.count,
            count_type: :records
          ),
          make_item(
            name: "Users",
            path: users_admin_index_path,
            count: User.count,
            count_type: :records
          ),
          make_item(
            name: "Card Designs",
            path: stripe_card_personalization_designs_admin_index_path,
            count: StripeCard::PersonalizationDesign.count,
            count_type: :records
          ),
          make_item(
            name: "Emails",
            path: emails_admin_index_path,
            count: Ahoy::Message.count,
            count_type: :records
          ),
          make_item(
            name: "Unknown Merchants",
            path: unknown_merchants_admin_index_path,
            count: Rails.cache.fetch("admin_unknown_merchants")&.length || 0,
            count_type: :records
          ),
          make_item(
            name: "Referral Programs",
            path: referral_programs_admin_index_path,
            count: Referral::Program.count,
            count_type: :records
          ),
          make_item(
            name: "Event Groups",
            path: admin_event_groups_path,
            count: Event::Group.count,
            count_type: :records,
          ),
          make_item(
            name: "Active Teenagers Leaderboard",
            path: active_teenagers_leaderboard_admin_index_path,
            count: User.active_teenager.count,
            count_type: :records,
          ),
          make_item(
            name: "New Teenagers Leaderboard",
            path: new_teenagers_leaderboard_admin_index_path,
            count: 0, # I think this would be expensive to calculate
            count_type: :records,
          ),
          make_item(
            name: "Public ID Lookup",
            path: public_id_lookup_admin_index_path,
            count: 0,
            count_type: :records,
          )
        ]
      )
    end

    def payroll
      Section.new(
        name: "Payroll",
        items: [
          make_item(
            name: "Employees",
            path: employees_admin_index_path,
            count: Employee.onboarding.count
          ),
          make_item(
            name: "Payments",
            path: employee_payments_admin_index_path,
            count: Employee::Payment.paid.count,
            count_type: :records
          ),
          make_item(
            name: "W9s",
            path: admin_w9s_path,
            count: W9.all.count,
            count_type: :records
          )
        ]
      )
    end

    def organizations
      Section.new(
        name: "Organizations",
        items: [
          make_item(
            name: "Organizations",
            path: events_admin_index_path,
            count: Event.approved.count,
            count_type: :records
          ),
          make_item(
            name: "Google Workspace Requests",
            path: google_workspaces_admin_index_path,
            count: GSuite.needs_ops_review.count
          ),

          make_item(
            name: "Account Numbers",
            path: account_numbers_admin_index_path,
            count: Column::AccountNumber.count,
            count_type: :records
          )
        ]
      )
    end

    def incoming_money
      Section.new(
        name: "Incoming Money",
        items: [
          make_item(
            name: "Donations",
            path: donations_admin_index_path,
            count: 0
          ),
          make_item(
            name: "Recurring Donations",
            path: recurring_donations_admin_index_path,
            count: 0
          ),
          make_item(
            name: "Invoices",
            path: invoices_admin_index_path,
            count: 0
          ),
          make_item(
            name: "Sponsors",
            path: sponsors_admin_index_path,
            count: 0
          )
        ]
      )
    end

    def ledger
      Section.new(
        name: "Ledger",
        items: [
          make_item(
            name: "Ledger",
            path: ledger_admin_index_path,
            count: CanonicalTransaction.not_stripe_top_up.unmapped.count
          ),
          make_item(
            name: "Pending Ledger",
            path: pending_ledger_admin_index_path,
            count: CanonicalPendingTransaction.unsettled.count,
            count_type: :records
          ),
          make_item(
            name: "Raw Transactions",
            path: raw_transactions_admin_index_path,
            count: RawCsvTransaction.unhashed.count
          ),
          make_item(
            name: "Intrafi Transactions",
            path: raw_intrafi_transactions_admin_index_path,
            count: RawIntrafiTransaction.count,
            count_type: :records
          ),
          make_item(
            name: "HCB codes",
            path: hcb_codes_admin_index_path,
            count: 0,
            count_type: :records
          ),
          make_item(
            name: "Audits",
            path: admin_ledger_audits_path,
            count: Admin::LedgerAudit.pending.count
          ),
        ]
      )
    end

    def spending
      Section.new(
        name: "Spending",
        items: [
          make_item(
            name: "ACHs",
            path: ach_admin_index_path,
            count: AchTransfer.pending.count
          ),
          make_item(
            name: "Checks",
            path: increase_checks_admin_index_path,
            count: IncreaseCheck.pending.count
          ),
          make_item(
            name: "Disbursements",
            path: disbursements_admin_index_path,
            count: Disbursement.reviewing.count
          ),
          make_item(
            name: "PayPal",
            path: paypal_transfers_admin_index_path,
            count: PaypalTransfer.pending.count
          ),
          make_item(
            name: "Wires",
            path: wires_admin_index_path,
            count: Wire.pending.count
          ),
          make_item(
            name: "Wise transfers",
            path: wise_transfers_admin_index_path,
            count: WiseTransfer.pending.count
          ),
          make_item(
            name: "Reimbursements",
            path: reimbursements_admin_index_path,
            count: Reimbursement::Report.reimbursement_requested.count
          )
        ]
      )
    end

  end
end
