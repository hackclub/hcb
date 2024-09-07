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
      self
    rescue NoMethodError => e
      puts "Add a datetime 'mark_no_or_lost_receipt_at' column to #{self.class.name} for this to work"

      raise e
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
