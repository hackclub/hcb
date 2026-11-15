# frozen_string_literal: true

module DisbursementService
  class Create
    include ::Shared::AmpleBalance

    # This service raises exceptions that should ideally be displayed to the end
    # user (e.g. insufficient funds) as they are best placed to address those
    # issues.
    class UserError < ArgumentError; end

    def initialize(
      source_event_id:,
      destination_event_id:,
      name:,
      amount:,
      requested_by_id:,
      fulfilled_by_id: nil,
      destination_subledger_id: nil,
      scheduled_on: nil,
      source_subledger_id: nil,
      should_charge_fee: false,
      skip_auto_approve: false,
      fronted: false,
      source_transaction_category_slug: nil,
      destination_transaction_category_slug: nil,
      category_assignment_strategy: "manual",
      transfer_type: nil,
      repaid_ledger_item_ids: []
    )
      @source_event_id = source_event_id
      @source_event = Event.find(@source_event_id)
      @destination_event_id = destination_event_id
      @destination_event = Event.find(@destination_event_id)
      @destination_subledger_id = destination_subledger_id
      @source_subledger_id = source_subledger_id
      @name = name
      @amount = amount
      @requested_by_id = requested_by_id
      @fulfilled_by_id = fulfilled_by_id
      @scheduled_on = scheduled_on
      @should_charge_fee = should_charge_fee
      @skip_auto_approve = skip_auto_approve
      @fronted = fronted
      @source_transaction_category_slug = source_transaction_category_slug
      @destination_transaction_category_slug = destination_transaction_category_slug
      @category_assignment_strategy = category_assignment_strategy
      @transfer_type = transfer_type
      @repaid_ledger_items = Ledger::Item.find(repaid_ledger_item_ids.uniq).sort_by(&:id)
    end

    def run
      raise ArgumentError, "amount is required" unless @amount
      raise ArgumentError, "amount_cents must be greater than 0" unless amount_cents > 0

      validate_transfer_type!

      @source_event.with_lock do
        if @source_subledger_id.present?
          raise UserError, "You don't have enough money to make this disbursement." unless Subledger.find(@source_subledger_id).card_grant.balance_cents >= amount_cents || requested_by_admin?
        else
          raise UserError, "You don't have enough money to make this disbursement." unless ample_balance?(amount_cents, @source_event) || requested_by_admin?
        end

        ActiveRecord::Base.transaction do
          # Two transfers repaying the same transaction at once would both
          # pass the "already repaid" check without this.
          @repaid_ledger_items.each(&:lock!)

          disbursement = Disbursement.new(attrs)
          if @repaid_ledger_items.any?
            repayment = disbursement.build_repayment
            @repaid_ledger_items.each do |item|
              repayment.allocations.build(repaid_ledger_item: item, amount_cents: -item.amount_cents)
            end
          end
          disbursement.save!
          disbursement.repayment&.allocations&.each(&:apply_categories!)

          # 1. Create the raw pending transactions
          rpodt = ::PendingTransactionEngine::RawPendingOutgoingDisbursementTransactionService::Disbursement::ImportSingle.new(disbursement:).run
          # 2. Canonize the newly added raw pending transactions
          o_cpt = ::PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::OutgoingDisbursement.new(raw_pending_outgoing_disbursement_transaction: rpodt, category_assignment_strategy: @category_assignment_strategy).run
          # 3. Map to event
          ::PendingEventMappingEngine::Map::Single::OutgoingDisbursement.new(canonical_pending_transaction: o_cpt).run
          # 4. Front if required
          o_cpt.update(fronted: @fronted)
          split_by_repaid_category!(o_cpt)

          if disbursement.scheduled_on.nil?
            # We only want to import Incoming Disbursements AFTER the scheduled date

            # 1. Create the raw pending transactions
            rpidt = ::PendingTransactionEngine::RawPendingIncomingDisbursementTransactionService::Disbursement::ImportSingle.new(disbursement:).run
            # 2. Canonize the newly added raw pending transactions
            i_cpt = ::PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::IncomingDisbursement.new(raw_pending_incoming_disbursement_transaction: rpidt, category_assignment_strategy: @category_assignment_strategy).run
            # 3. Map to event
            ::PendingEventMappingEngine::Map::Single::IncomingDisbursement.new(canonical_pending_transaction: i_cpt).run
            # 4. Front if required
            i_cpt.update(fronted: @fronted)
          end

          if requested_by_admin_with_approval_permission?(disbursement) || disbursement.source_event == disbursement.destination_event # Auto-fulfill disbursements between subledgers in the same event
            disbursement.approve_by_admin(requested_by)
          end

          disbursement
        end
      end
    end

    private

    def attrs
      {
        source_event_id: source_event.id,
        event_id: destination_event.id,
        destination_subledger_id: @destination_subledger_id,
        source_subledger_id: @source_subledger_id,
        scheduled_on: @scheduled_on,
        name: @name,
        amount: amount_cents,
        requested_by:,
        should_charge_fee: @should_charge_fee,
        transfer_type: @transfer_type,
        source_transaction_category:,
        destination_transaction_category:
      }
    end

    def requested_by
      @requested_by ||= User.find @requested_by_id if @requested_by_id
    end

    def requested_by_admin?
      !@skip_auto_approve && requested_by&.admin?
    end

    def requested_by_admin_with_approval_permission?(disbursement)
      requested_by_admin? && GovernanceService::Admin::Transfer::Approval.new(
        transfer: disbursement,
        amount_cents: disbursement.amount,
        user: requested_by,
      ).may_approve?
    end

    def amount_cents
      Monetize.parse(@amount).cents
    end

    def source_event
      @source_event ||= Event.find(@source_event_id)
    end

    def destination_event
      @destination_event ||= Event.find(@destination_event_id)
    end

    def validate_transfer_type!
      raise UserError, "Choose what kind of transfer this is." unless Disbursement.transfer_types.key?(@transfer_type)

      raise UserError, "Choose the transactions you're repaying." if @transfer_type == "repayment" && @repaid_ledger_items.empty?
      raise UserError, "Only repayments can repay transactions." if @transfer_type != "repayment" && @repaid_ledger_items.any?
    end

    # An explicit slug (from admins, or HCB-created transfers like card grants)
    # wins over the one implied by the transfer type.
    def source_transaction_category_slug
      return @source_transaction_category_slug if @source_transaction_category_slug.present?

      case @transfer_type
      when "transfer" then "internal-transfer"
      # A transfer has one category, so it only inherits one the expenses
      # share. Otherwise it's split by category (see split_by_repaid_category!).
      when "repayment"
        repaid_items_by_category_slug.keys.first if repaid_items_by_category_slug.size == 1
      end
    end

    # The repaid expenses under each category's slug (nil for uncategorized).
    # Memoized because repaying them recategorizes them as repayments.
    def repaid_items_by_category_slug
      @repaid_items_by_category_slug ||= @repaid_ledger_items.group_by { |item| Repayment::Allocation.new(repaid_ledger_item: item).repaid_category&.slug }
    end

    # When the repaid expenses' categories differ, the sender's side carries
    # each category for its share of the transfer, so the sender's reports show
    # what the money was spent on. Uncategorized expenses stay with the rest of
    # the transaction, which has no category of its own.
    def split_by_repaid_category!(pending_transaction)
      return if @source_transaction_category_slug.present? || repaid_items_by_category_slug.size < 2

      repaid_items_by_category_slug.each do |slug, items|
        next if slug.nil?

        pending_transaction.splits.create!(
          amount_cents: items.sum(&:amount_cents),
          category: TransactionCategory.find_or_create_by!(slug:),
          memo: items.one? ? "Repaying #{items.first.memo}" : "Repaying #{items.size} expenses"
        )
      end
    end

    def destination_transaction_category_slug
      return @destination_transaction_category_slug if @destination_transaction_category_slug.present?

      case @transfer_type
      when "transfer" then "internal-transfer"
      when "repayment" then Repayment::CATEGORY_SLUG
      end
    end

    def source_transaction_category
      slug = source_transaction_category_slug
      return if slug.blank?

      @source_transaction_category ||= TransactionCategory.find_or_create_by!(slug:)
    end

    def destination_transaction_category
      slug = destination_transaction_category_slug
      return if slug.blank?

      @destination_transaction_category ||= TransactionCategory.find_or_create_by!(slug:)
    end

  end
end
