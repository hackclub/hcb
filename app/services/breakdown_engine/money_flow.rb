# frozen_string_literal: true

module BreakdownEngine
  class MoneyFlow
    LABELS_BY_CODE = {
      TransactionGroupingEngine::Calculate::HcbCode::INVOICE_CODE                    => "Invoices",
      TransactionGroupingEngine::Calculate::HcbCode::DONATION_CODE                   => "Donations",
      TransactionGroupingEngine::Calculate::HcbCode::PARTNER_DONATION_CODE           => "Donations",
      TransactionGroupingEngine::Calculate::HcbCode::ACH_TRANSFER_CODE               => "ACH transfers",
      TransactionGroupingEngine::Calculate::HcbCode::WIRE_CODE                       => "Wires",
      TransactionGroupingEngine::Calculate::HcbCode::PAYPAL_TRANSFER_CODE            => "PayPal transfers",
      TransactionGroupingEngine::Calculate::HcbCode::WISE_TRANSFER_CODE              => "Wise transfers",
      TransactionGroupingEngine::Calculate::HcbCode::CHECK_CODE                      => "Checks",
      TransactionGroupingEngine::Calculate::HcbCode::INCREASE_CHECK_CODE             => "Checks",
      TransactionGroupingEngine::Calculate::HcbCode::CHECK_DEPOSIT_CODE              => "Check deposits",
      TransactionGroupingEngine::Calculate::HcbCode::OUTGOING_DISBURSEMENT_CODE      => "Transfers out",
      TransactionGroupingEngine::Calculate::HcbCode::INCOMING_DISBURSEMENT_CODE      => "Transfers in",
      TransactionGroupingEngine::Calculate::HcbCode::STRIPE_SERVICE_FEE_CODE         => "Card fees",
      TransactionGroupingEngine::Calculate::HcbCode::BANK_FEE_CODE                   => "HCB fees",
      TransactionGroupingEngine::Calculate::HcbCode::INCOMING_BANK_FEE_CODE          => "HCB fees",
      TransactionGroupingEngine::Calculate::HcbCode::OUTGOING_FEE_REIMBURSEMENT_CODE => "HCB fees",
      TransactionGroupingEngine::Calculate::HcbCode::FEE_REVENUE_CODE                => "Fee revenue",
      TransactionGroupingEngine::Calculate::HcbCode::EXPENSE_PAYOUT_CODE             => "Reimbursements",
      TransactionGroupingEngine::Calculate::HcbCode::PAYOUT_HOLDING_CODE             => "Reimbursements",
    }.freeze

    EXPENSE_GROUPS = {
      "Transfers" => ["ACH transfers", "Wires", "PayPal transfers", "Wise transfers", "Checks", "Transfers out", "Reimbursements"],
      "Fees"      => ["HCB fees", "Card fees"],
    }.freeze
    CARD_GROUP = "Card spending"
    BALANCE = "Balance"

    def initialize(event, start_date: nil, end_date: Time.now)
      @event = event
      @start_date = start_date
      @end_date = end_date
    end

    def run
      net_cents_by_label = Hash.new(0)
      non_card_totals.each do |code, amount_cents|
        net_cents_by_label[LABELS_BY_CODE.fetch(code, "Other")] += amount_cents
      end

      net_cents_by_card_category = Hash.new(0)
      card_totals.each do |merchant_category, amount_cents|
        label = merchant_category.present? ? BreakdownEngine::Categorizer.new(merchant_category).run.humanize : "Uncategorized"
        net_cents_by_card_category[label] += amount_cents
      end

      income = consolidate(
        net_cents_by_label.merge(net_cents_by_card_category) { |_, a, b| a + b }.select { |_, cents| cents.positive? },
        other_label: "Other income"
      )

      spending_by_group = Hash.new { |hash, group| hash[group] = {} }
      net_cents_by_label.each do |label, cents|
        next unless cents.negative?

        group = EXPENSE_GROUPS.find { |_, labels| labels.include?(label) }&.first
        spending_by_group[group][label == "Other" ? "Other spending" : label] = cents.abs
      end
      net_cents_by_card_category.each do |label, cents|
        spending_by_group[CARD_GROUP][label] = cents.abs if cents.negative?
      end

      expenses = expense_tree(spending_by_group)

      money_in_cents = income.values.sum
      money_out_cents = expenses.sum { |_, cents, _| cents }
      totals = { money_in_cents:, money_out_cents: }

      return { nodes: [], links: [], **totals } if income.empty? && expenses.empty?

      difference = money_in_cents - money_out_cents
      income[BALANCE] = -difference if difference.negative?
      expenses << [BALANCE, difference, {}] if difference.positive?

      build_graph(income, expenses).merge(totals)
    end

    private

    def transactions
      scope = @event.canonical_transactions
      scope = scope.where(date: @start_date.to_date..) if @start_date.present?
      scope = scope.where(date: ..@end_date.to_date) if @end_date.present?
      scope
    end

    def non_card_totals
      transactions
        .where("canonical_transactions.transaction_source_type IS DISTINCT FROM 'RawStripeTransaction'")
        .group(Arel.sql("split_part(canonical_transactions.hcb_code, '-', 2)"))
        .sum("canonical_transactions.amount_cents")
    end

    def card_totals
      transactions
        .where(transaction_source_type: "RawStripeTransaction")
        .joins("INNER JOIN raw_stripe_transactions ON raw_stripe_transactions.id = canonical_transactions.transaction_source_id")
        .group(Arel.sql("lower(trim(split_part(raw_stripe_transactions.stripe_transaction->'merchant_data'->>'category', '*', 1)))"))
        .sum("canonical_transactions.amount_cents")
    end

    def expense_tree(spending_by_group)
      entries = spending_by_group.flat_map do |group, cents_by_label|
        next cents_by_label.map { |label, cents| [label, cents, {}] } if group.nil?

        children = consolidate(cents_by_label, other_label: "Other #{group.downcase}")
        next children.map { |label, cents| [label, cents, {}] } if children.size == 1

        [[group, children.values.sum, children]]
      end

      entries.sort_by { |name, cents, _| [name == "Other spending" ? 1 : 0, -cents] }
    end

    def build_graph(income, expenses)
      nodes = []
      links = []
      add_node = lambda do |name, kind|
        nodes << { name:, kind: }
        nodes.size - 1
      end
      add_link = ->(source, target, cents) { links << { source:, target:, value: cents / 100.0 } }

      income_indexes = income.map { |name, cents| [add_node.call(name, name == BALANCE ? "balance" : "income"), cents] }
      hub = add_node.call(@event.name, "hub")
      income_indexes.each { |index, cents| add_link.call(index, hub, cents) }

      expenses.each do |name, cents, children|
        kind = if name == BALANCE
                 "balance"
               else
                 children.empty? ? "expense" : "group"
               end
        node = add_node.call(name, kind)
        add_link.call(hub, node, cents)
        children.each { |child, child_cents| add_link.call(node, add_node.call(child, "expense"), child_cents) }
      end

      { nodes:, links: }
    end

    def consolidate(cents_by_label, other_label:)
      total = cents_by_label.values.sum
      sorted = cents_by_label.sort_by { |label, cents| [label == "Other" ? 1 : 0, -cents] }

      kept, folded = sorted.partition.with_index do |(label, cents), i|
        label != "Other" && i < 8 - 1 && cents >= total * 0.03 # if its less than 3% it's just folding it into an other category for consolidation purposes
      end

      result = kept.to_h
      other_cents = folded.sum { |_, cents| cents }
      result[other_label] = other_cents if other_cents.positive?
      result
    end

  end
end
