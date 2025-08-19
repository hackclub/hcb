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

end
