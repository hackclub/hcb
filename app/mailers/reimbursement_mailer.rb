# frozen_string_literal: true

class ReimbursementMailer < ApplicationMailer
  def invitation
    @report = params[:report]

    mail to: @report.user.email_address_with_name, subject: "Get reimbursed by #{@report.event.name} for #{@report.name}", from: hcb_email_with_name_of(@report.event), reply_to: @report.user == @report.inviter ? nil : @report.inviter.email_address_with_name
  end

  def reimbursement_approved
    @report = params[:report]

    mail to: @report.user.email_address_with_name, subject: "[Reimbursements] Approved: #{@report.name}", from: hcb_email_with_name_of(@report.event)
  end

  def rejected
    @report = params[:report]

    mail to: @report.user.email_address_with_name, subject: "[Reimbursements] Rejected: #{@report.name}", from: hcb_email_with_name_of(@report.event)
  end

  def review_requested
    @report = params[:report]

    if @report.reviewer.present?
      mail to: @report.reviewer.email_address_with_name, subject: "[Reimbursements / #{@report.event.name}] Your Review Was Requested: #{@report.name}"
    else
      mail to: @report.event.users.excluding(@report.user).map(&:email_address_with_name), subject: "[Reimbursements / #{@report.event.name}] Review Requested: #{@report.name}"
    end
  end

  def expense_approved
    @report = params[:report]
    @expense = params[:expense]

    mail to: @report.user.email_address_with_name, subject: "An update on your reimbursement for #{@expense.memo}", from: hcb_email_with_name_of(@report.event)
  end

  def expense_unapproved
    @report = params[:report]
    @expense = params[:expense]

    mail to: @report.user.email_address_with_name, subject: "An update on your reimbursement for #{@expense.memo}", from: hcb_email_with_name_of(@report.event)
  end

  def ach_failed
    @payout_holding = params[:reimbursement_payout_holding]
    @report = @payout_holding.report
    @reason = params[:reason]

    mail subject: "[Reimbursements] ACH transfer for #{@report.name} failed to send", to: @report.user.email_address_with_name
  end

end
