# frozen_string_literal: true

module Admin
  class Nav
    include Rails.application.routes.url_helpers
    prepend MemoWise

    class Section
      prepend MemoWise
      attr_reader(:name, :items, :icon)

      def initialize(name:, items:, icon: nil)
        @name = name
        @items = items
        @icon = icon
      end

      def active?
        items.any?(&:active?)
      end

      memo_wise(:active?)

      def path
        items.find { |item| !item.divider? }&.path
      end

      memo_wise(:path)

      def task_sum
        items.sum { |item| item.count || 0 }
      end

      memo_wise(:task_sum)

    end

    class Group
      attr_reader(:name, :sections)

      def initialize(name:, sections:)
        @name = name
        @sections = sections
      end

    end

    class Item
      attr_reader(:name, :path)

      def initialize(name:, path:, count: nil, active: false, divider: false)
        @name = name
        @path = path
        @count_lambda = count
        @active = active
        @divider = divider
      end

      def count
        @count ||= @count_lambda&.call
      end

      def active?
        @active
      end

      def divider?
        @divider
      end

      # Whether this item shows a task count (doesn't run the count query).
      def task_count?
        !@count_lambda.nil?
      end

    end

    def initialize(page_title:)
      @page_title = page_title
    end

    def groups
      [
        Group.new(
          name: "Money",
          sections: [
            incoming_money,
            spending,
            ledger,
            cards,
            financials
          ]
        ),
        Group.new(
          name: "Organizations & People",
          sections: [
            organizations,
            payroll,
            users,
            documents,
            leaderboards
          ]
        )
      ]
    end

    memo_wise(:groups)

    def sections
      groups.flat_map(&:sections)
    end

    memo_wise(:sections)

    def section_names
      sections.map(&:name)
    end

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

    def make_divider(name:)
      Item.new(
        active: false,
        divider: true,
        name:,
        path: "#"
      )
    end

    # `match_title` lets an item carry a short sidebar label while still
    # highlighting for a longer page title (e.g. "New Teenagers" under the
    # Leaderboards divider vs. "New Teenagers Leaderboard").
    def make_item(name:, match_title: name, **properties)
      Item.new(
        name:,
        **properties,
        active: normalize_string(match_title) == normalized_page_title
      )
    end

    def spending
      Section.new(
        name: "Spending",
        icon: "door-leave",
        items: [
          make_item(
            name: "ACH Transfers",
            path: ach_admin_index_path,
            count: ->{ AchTransfer.pending.count }
          ),
          make_item(
            name: "Checks",
            path: increase_checks_admin_index_path,
            count: ->{ IncreaseCheck.pending.count }
          ),
          make_item(
            name: "Disbursements",
            path: disbursements_admin_index_path,
            count: ->{ Disbursement.reviewing.count }
          ),
          make_item(
            name: "Wires",
            path: wires_admin_index_path,
            count: ->{ Wire.pending.count }
          ),
          make_item(
            name: "Wire Lookup",
            path: wire_lookup_admin_index_path
          ),
          make_item(
            name: "Wise Transfers",
            path: wise_transfers_admin_index_path,
            count: ->{ WiseTransfer.pending.count }
          ),
          make_item(
            name: "Reimbursements",
            path: reimbursements_admin_index_path,
            count: ->{ Reimbursement::Report.reimbursement_requested.count }
          ),
          make_item(
            name: "Payments",
            path: admin_payments_path,
            count: ->{ Payment.under_review.count }
          )
        ]
      )
    end

    def ledger
      Section.new(
        name: "Ledger",
        icon: "card-list",
        items: [
          make_item(
            name: "Ledger",
            path: ledger_admin_index_path,
            count: ->{ CanonicalTransaction.not_stripe_top_up.unmapped.count }
          ),
          make_item(
            name: "Pending Ledger",
            path: pending_ledger_admin_index_path
          ),
          make_item(
            name: "Ledger Items",
            path: ledger_items_admin_index_path
          ),
          make_item(
            name: "Raw Transactions",
            path: raw_transactions_admin_index_path
          ),
          make_item(
            name: "Intrafi Transactions",
            path: raw_intrafi_transactions_admin_index_path
          ),
          make_item(
            name: "HCB Codes",
            path: hcb_codes_admin_index_path
          ),
          make_item(
            name: "Unknown Merchants",
            path: unknown_merchants_admin_index_path
          ),
          make_item(
            name: "Audits",
            path: admin_ledger_audits_path,
            count: ->{ Admin::LedgerAudit.pending.count }
          ),
        ]
      )
    end

    def incoming_money
      Section.new(
        name: "Incoming",
        icon: "door-enter",
        items: [
          make_item(
            name: "Donations",
            path: donations_admin_index_path
          ),
          make_item(
            name: "Recurring Donations",
            path: recurring_donations_admin_index_path
          ),
          make_item(
            name: "Invoices",
            path: invoices_admin_index_path
          ),
          make_item(
            name: "Sponsors",
            path: sponsors_admin_index_path
          ),
          make_item(
            name: "Check Deposits",
            path: admin_check_deposits_path,
            count: ->{ CheckDeposit.unprocessed.count }
          )
        ]
      )
    end

    def organizations
      Section.new(
        name: "Organizations",
        icon: "event-check",
        items: [
          make_item(
            name: "Applications (HCB)",
            path: applications_admin_index_path,
            count: ->{ Event::Application.under_review.count }
          ),
          make_item(
            name: "Organizations",
            path: events_admin_index_path
          ),
          make_item(
            name: "Event Groups",
            path: admin_event_groups_path
          ),
          make_item(
            name: "Organization Balances",
            path: balances_admin_index_path
          ),
          make_item(
            name: "OPDRs",
            path: organizer_position_deletion_requests_path
          ),
          make_item(
            name: "Google Workspaces",
            path: google_workspaces_admin_index_path,
            count: ->{ GSuite.needs_ops_review.count }
          ),
          make_item(
            name: "Account Numbers",
            path: account_numbers_admin_index_path
          )
        ]
      )
    end

    def payroll
      Section.new(
        name: "Payroll",
        icon: "person-badge",
        items: [
          make_item(
            name: "Contractors",
            path: admin_payroll_positions_path,
            count: ->{ Payroll::Position.under_review.count }
          ),
          make_item(
            name: "Legal Entities",
            path: admin_legal_entities_path
          ),
          make_item(
            name: "Tax Forms",
            path: admin_tax_forms_path
          ),
          make_item(
            name: "Tax1099 Import",
            path: new_admin_tax1099_import_path
          )
        ]
      )
    end

    def cards
      Section.new(
        name: "Cards",
        icon: "card",
        items: [
          make_item(
            name: "Stripe Cards",
            path: stripe_cards_admin_index_path
          ),
          make_item(
            name: "Card Designs",
            path: stripe_card_personalization_designs_admin_index_path
          )
        ]
      )
    end

    def documents
      Section.new(
        name: "Documents",
        icon: "docs",
        items: [
          make_item(
            name: "Common Documents",
            path: common_documents_path
          ),
          make_item(
            name: "Contracts",
            path: contracts_admin_index_path
          )
        ]
      )
    end

    def financials
      Section.new(
        name: "Financials",
        icon: "bank-account",
        items: [
          make_item(
            name: "Bank Accounts",
            path: bank_accounts_admin_index_path
          ),
          make_item(
            name: "HCB Fees",
            path: bank_fees_admin_index_path
          ),
          make_item(
            name: "Fee Revenues",
            path: fee_revenues_admin_index_path
          ),
          make_item(
            name: "Column Statements",
            path: admin_column_statements_path
          )
        ]
      )
    end

    def users
      Section.new(
        name: "Users",
        icon: "people-2",
        items: [
          make_item(
            name: "Users",
            path: users_admin_index_path
          ),
          make_item(
            name: "Emails",
            path: emails_admin_index_path
          ),
          make_item(
            name: "Referral Programs",
            path: referral_programs_admin_index_path
          )
        ]
      )
    end

    def leaderboards
      Section.new(
        name: "Leaderboards",
        icon: "leader",
        items: [
          make_item(
            name: "Active Teenagers",
            match_title: "Active Teenagers Leaderboard",
            path: active_teenagers_leaderboard_admin_index_path
          ),
          make_item(
            name: "New Teenagers",
            match_title: "New Teenagers Leaderboard",
            path: new_teenagers_leaderboard_admin_index_path
          )
        ]
      )
    end

  end
end
