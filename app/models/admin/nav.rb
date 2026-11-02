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
        items.sum { |item| item.count || 0 }
      end

      memo_wise(:task_sum)

    end

    class Item
      attr_reader(:name, :path)

      def initialize(name:, path:, count: nil, active: false)
        @name = name
        @path = path
        @count_lambda = count
        @active = active
      end

      def count
        @count ||= @count_lambda&.call
      end

      def active?
        @active
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

    def section_names
      [
        "Spending",
        "Ledger",
        "Incoming Money",
        "Organizations",
        "Payroll",
        "Misc"
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

    def spending
      Section.new(
        name: "Spending",
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
        name: "Incoming Money",
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
          )
        ]
      )
    end

    def misc
      Section.new(
        name: "Misc",
        items: [
          make_item(
            name: "Blazer",
            path: blazer_path
          ),
          make_item(
            name: "Flipper",
            path: flipper_path
          ),
          make_item(
            name: "Common Documents",
            path: common_documents_path
          ),
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
          ),
          make_item(
            name: "Users",
            path: users_admin_index_path
          ),
          make_item(
            name: "Stripe Cards",
            path: stripe_cards_admin_index_path
          ),
          make_item(
            name: "Card Designs",
            path: stripe_card_personalization_designs_admin_index_path
          ),
          make_item(
            name: "Emails",
            path: emails_admin_index_path
          ),
          make_item(
            name: "Referral Programs",
            path: referral_programs_admin_index_path
          ),
          make_item(
            name: "Event Groups",
            path: admin_event_groups_path
          ),
          make_item(
            name: "Contracts",
            path: contracts_admin_index_path
          ),
          make_item(
            name: "Active Teenagers Leaderboard",
            path: active_teenagers_leaderboard_admin_index_path
          ),
          make_item(
            name: "New Teenagers Leaderboard",
            path: new_teenagers_leaderboard_admin_index_path
          )
        ]
      )
    end

  end
end
