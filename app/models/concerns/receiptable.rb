# frozen_string_literal: true

module Receiptable
  extend ActiveSupport::Concern

  included do
    include IsTaskable

    has_many :receipts, as: :receiptable, after_add: :update_task_completion, after_remove: :update_task_completion

    scope :without_receipt, -> { includes(:receipts).where(receipts: { receiptable_id: nil }) }
    scope :missing_receipt, -> { without_receipt.where(marked_no_or_lost_receipt_at: nil) }
    scope :with_receipt, -> { includes(:receipts).where.not(receipts: { receiptable_id: nil }) }
    scope :lost_receipt, -> { where.not(marked_no_or_lost_receipt_at: nil) }
    scope :has_receipt_or_marked_no_or_lost, -> { with_receipt.or(lost_receipt) }

    def receipt_required?
      # This method should be overwritten in specific classes
      raise NotImplementedError, "The #{self.class.name} model includes Receiptable, but hasn't implemented it's own version of receipt_required?."
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

    # An HCB code and its ledger item each keep their own copy of the mark: the
    # ledger item's copy backs `Ledger::Item#missing_receipt?` and the ledger
    # filters, the HCB code's backs everything else. Marking either one has to
    # mark the other, whichever side the mark came from.
    # TODO: this is temporary syncing logic. Long term the mark should only live
    # on the ledger item.
    def no_or_lost_receipt_counterpart
      case self
      when HcbCode then ledger_item
      when ::Ledger::Item then hcb_code
      end
    end

    def sync_no_or_lost_receipt!
      counterpart = no_or_lost_receipt_counterpart
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
end
