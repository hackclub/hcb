# frozen_string_literal: true

module Api
  module Models
    # Presents a Ledger::Item through the interface that Api::Entities::Transaction
    # (and, via LinkedObjectBase, every linked object entity) expects from an
    # HcbCode. This lets the v3 serializers run on the new transaction engine
    # without forking them into a parallel set of entities.
    #
    # Only the methods those entities actually call are defined here; everything
    # else falls through to the Ledger::Item.
    class LedgerTransaction < SimpleDelegator
      HEADER = "X-HCB-Transaction-Engine"
      LEDGER = "ledger"
      ENV_KEY = "HTTP_#{HEADER.upcase.tr("-", "_")}".freeze

      TYPES = {
        "Invoice"                      => :invoice,
        "Donation"                     => :donation,
        "AchTransfer"                  => :ach,
        "Check"                        => :check,
        "IncreaseCheck"                => :check,
        "CardCharge"                   => :card_charge,
        "Wire"                         => :wire,
        "WiseTransfer"                 => :wise_transfer,
        "PaypalTransfer"               => :paypal_transfer,
        "CheckDeposit"                 => :check_deposit,
        "BankFee"                      => :bank_fee,
        "Reimbursement::ExpensePayout" => :reimbursement_expense_payout,
        "Disbursement::Outgoing"       => :disbursement,
        "Disbursement::Incoming"       => :disbursement,
        nil                            => :unknown
      }.freeze

      READERS = {
        ach_transfer: "AchTransfer",
        check: "Check",
        increase_check: "IncreaseCheck",
        donation: "Donation",
        invoice: "Invoice",
        wire: "Wire",
        wise_transfer: "WiseTransfer",
        paypal_transfer: "PaypalTransfer",
        check_deposit: "CheckDeposit",
        bank_fee: "BankFee",
        reimbursement_expense_payout: "Reimbursement::ExpensePayout",
        outgoing_disbursement: "Disbursement::Outgoing",
        incoming_disbursement: "Disbursement::Incoming"
      }.freeze

      READERS.each do |name, type|
        define_method(name) { linked_object_type == type ? linked_object : nil }
        define_method(:"#{name}?") { linked_object_type == type }
      end

      def self.requested?(request)
        request.get_header(ENV_KEY).to_s.casecmp?(LEDGER)
      end

      def self.resolve(linked_object, options = {})
        item = linked_object.try(:ledger_item) if options[:ledger]

        item ? new(item) : linked_object.local_hcb_code
      end

      # v3 ids stay HcbCode-derived; the ledger item's id is exposed separately
      # as `ledger_item_id`.
      def public_id = hcb_code&.public_id

      def local_hcb_code = hcb_code

      # Api::Entities::Transaction exposes this as `ledger_item_id`.
      def ledger_item = __getobj__

      def event = primary_ledger&.event

      def date = datetime&.to_date

      def memo(event: nil) = __getobj__.memo

      def not_admin_only_comments_count = not_admin_only_comment_count

      def type
        return :card_grant if special_appearance&.key == "card_grant"

        TYPES[linked_object_type]
      end

    end
  end
end
