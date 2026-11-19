# frozen_string_literal: true

module BreakdownEngine
  class MoneyFlow
    LABELS_BY_TYPE = {
      "Invoice"                      => "Invoices",
      "Donation"                     => "Donations",
      "AchTransfer"                  => "ACH transfers",
      "Wire"                         => "Wires",
      "PaypalTransfer"               => "PayPal transfers",
      "WiseTransfer"                 => "Wise transfers",
      "Check"                        => "Checks",
      "IncreaseCheck"                => "Checks",
      "CheckDeposit"                 => "Check deposits",
      "Disbursement::Outgoing"       => "Transfers out",
      "Disbursement::Incoming"       => "Transfers in",
      "StripeServiceFee"             => "Stripe fees",
      "BankFee"                      => "HCB fees",
      "FeeReimbursementGroup"        => "Stripe fees",
      "FeeRevenue"                   => "Fee revenue",
      "Reimbursement::ExpensePayout" => "Reimbursements",
      "Reimbursement::PayoutHolding" => "Reimbursements",
    }.freeze

    EXPENSE_GROUPS = {
      "Transfers" => ["ACH transfers", "Wires", "PayPal transfers", "Wise transfers", "Checks", "Transfers out", "Reimbursements"],
      "Fees"      => ["HCB fees", "Stripe fees"],
    }.freeze
    CARD_GROUP = "Card spending"
    BALANCE = "Balance"
    MAX_NODES = 8
    MIN_SHARE = 0.03

    def initialize(event, start_date: nil, end_date: Time.now)
      @event = event
      @start_date = start_date
      @end_date = end_date
    end

    def run
      net_cents_by_label = Hash.new(0)
      non_card_totals.each do |linked_object_type, amount_cents|
        net_cents_by_label[LABELS_BY_TYPE.fetch(linked_object_type, "Other")] += amount_cents
      end

      net_cents_by_card_category = Hash.new(0)
      card_totals.each do |merchant_category, amount_cents|
        label = merchant_category.present? ? BreakdownEngine::Categorizer.new(merchant_category).run.humanize : "Uncategorized"
        net_cents_by_card_category[label] += amount_cents
      end

      income_by_label = net_cents_by_label.select { |_, cents| cents.positive? }
      card_refund_cents = net_cents_by_card_category.values.select(&:positive?).sum
      income_by_label["Card refunds"] = card_refund_cents if card_refund_cents.positive?
      income = consolidate(income_by_label, other_label: "Other income")

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

      totals = gross_totals

      return { nodes: [], links: [], **totals } if income.empty? && expenses.empty?

      difference = income.values.sum - expenses.sum { |_, cents, _| cents }
      income[BALANCE] = -difference if difference.negative?
      expenses << [BALANCE, difference, {}] if difference.positive?

      build_graph(income, expenses).merge(totals)
    end

    private

    def items
      Ledger::Query.new({
                          "$and": [
                            ({ datetime: { "$gte": @start_date.to_date } } if @start_date.present?),
                            ({ datetime: { "$lt": @end_date.to_date.next_day } } if @end_date.present?)
                          ].compact
                        }).execute(ledgers: [@event.ledger]).unscope(:order)
    end

    def non_card_totals
      items
        .where("ledger_items.linked_object_type IS DISTINCT FROM ?", "CardCharge")
        .group(:linked_object_type)
        .sum(:amount_cents)
    end

    def gross_totals
      { money_in_cents: items.where("ledger_items.amount_cents > 0").sum(:amount_cents), money_out_cents: -items.where("ledger_items.amount_cents < 0").sum(:amount_cents) }
    end

    def card_totals
      items
        .where(linked_object_type: "CardCharge")
        .joins("INNER JOIN card_charges ON card_charges.id = ledger_items.linked_object_id")
        .group(Arel.sql("lower(trim(split_part(card_charges.merchant_category, '*', 1)))"))
        .sum("ledger_items.amount_cents")
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
        label != "Other" && i < MAX_NODES - 1 && cents >= total * MIN_SHARE
      end

      result = kept.to_h
      other_cents = folded.sum { |_, cents| cents }
      result[other_label] = other_cents if other_cents.positive?
      result
    end

  end
end
