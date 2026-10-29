# frozen_string_literal: true

class ReimbursementMailerPreview < ActionMailer::Preview
  def invitation
    @report = Reimbursement::Report.last
    ReimbursementMailer.with(report: @report).invitation
  end

  def reimbursement_approved
    @report = Reimbursement::Report.last
    ReimbursementMailer.with(report: @report).reimbursement_approved
  end

  def rejected
    @report = Reimbursement::Report.last
    ReimbursementMailer.with(report: @report).rejected
  end

  def review_requested
    @report = Reimbursement::Report.last
    ReimbursementMailer.with(report: @report).review_requested
  end

  def wise_transfer_failed
    @payout_holding = Reimbursement::PayoutHolding.where.not(wise_transfer_id: nil).last
    ReimbursementMailer.with(reimbursement_payout_holding: @payout_holding, reason: "The recipient's account details were invalid").wise_transfer_failed
  end

  def failed_payout_reminder
    @payout_holding = Reimbursement::PayoutHolding.last
    @payout_holding.failed_at ||= 3.days.ago
    ReimbursementMailer.with(reimbursement_payout_holding: @payout_holding).failed_payout_reminder
  end

  def expenses_approved
    @expense = Reimbursement::Expense.last
    @report = @expense.report
    ReimbursementMailer.with(report: @report, expenses: [@expense]).expenses_approved
  end

end
