# frozen_string_literal: true

module Receiptable
  extend ActiveSupport::Concern

  included do
    include IsTaskable

    has_many :receipts, as: :receiptable, after_add: :update_task_completion, after_remove: :update_task_completion

    scope :without_receipt, -> { where.not(receipts_exist_sql) }
    scope :missing_receipt, -> { without_receipt.where(marked_no_or_lost_receipt_at: nil) }
    scope :with_receipt, -> { where(receipts_exist_sql) }
    scope :lost_receipt, -> { where.not(marked_no_or_lost_receipt_at: nil) }
    scope :has_receipt_or_marked_no_or_lost, -> { with_receipt.or(lost_receipt) }

    def receipt_required?
      # This method should be overwritten in specific classes
      raise NotImplementedError, "The #{self.class.name} model includes Receiptable, but hasn't implemented its own version of receipt_required?."
    end

    def missing_receipt?
      receipt_required? && without_receipt? && !no_or_lost_receipt?
    end

    def without_receipt?
      receipts.none?
    end

    def no_or_lost_receipt?
      !marked_no_or_lost_receipt_at.nil?
    end

    def no_or_lost_receipt!
      self.marked_no_or_lost_receipt_at = Time.now
      self.save!
      sync_no_or_lost_receipt!
      ::CardLocking::ReceiptResolution.on_no_or_lost_receipt(self)
      self
    rescue NoMethodError => e
      puts "Add a datetime 'mark_no_or_lost_receipt_at' column to #{self.class.name} for this to work"

      raise e
    end

    # An HCB code and its ledger item are two records for the same transaction,
    # and each keeps its own copy of the no/lost receipt mark: the ledger item's
    # copy backs `Ledger::Item#missing_receipt?` and the ledger filters, the HCB
    # code's backs everything else. Marking either one has to mark the other,
    # whichever side the mark came from.
    # TODO: this is temporary syncing logic. Long term the mark should only live
    # on the ledger item.
    def receipt_counterpart
      case self
      when HcbCode then ledger_item
      when ::Ledger::Item then hcb_code
      end
    end

    # The HCB code a receipt on this record belongs to: the code itself, or the
    # ledger item's code. Nil for every other receiptable, including the
    # transaction-like records (CanonicalTransaction, Transaction, ...) that have
    # a `local_hcb_code`, so a receipt on those keeps the generic behavior.
    # TODO: drop alongside #receipt_counterpart once the HCB code pages have
    # been replaced by the ledger item's.
    def receipt_hcb_code
      case self
      when HcbCode then self
      when ::Ledger::Item then hcb_code
      end
    end

    def sync_no_or_lost_receipt!
      counterpart = receipt_counterpart
      return if counterpart.nil?
      return if counterpart.marked_no_or_lost_receipt_at == marked_no_or_lost_receipt_at

      counterpart.update!(marked_no_or_lost_receipt_at:)
    end

    after_create_commit do
      safely do
        assignee = try(:author) || try(:user) || try(:event)
        if missing_receipt? && assignee
          Task::Receiptable::Upload.create!(taskable: self, assignee:)
        end
      end
    end
  end

  class_methods do
    # SQL that holds when the row has a receipt, for the scopes above and for
    # the raw queries that filter transactions by receipt. Keyed on the row's
    # own id; HcbCode overrides it to look at its ledger item's id instead,
    # since that is where a transaction's receipts live (see HcbCode#receipts).
    def receipts_exist_sql
      "EXISTS (#{Receipt.select("1").where("receipts.receiptable_type = ? AND receipts.receiptable_id = #{table_name}.id", polymorphic_name).to_sql})"
    end
  end
end
