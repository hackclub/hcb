# frozen_string_literal: true

class ReimbursementMailer < ApplicationMailer
  before_action { @report = params[:report] || params[:reimbursement_payout_holding]&.report }
  before_action(only: [:invitation, :reminder]) { @delivery_reason = "you were invited to submit a reimbursement report for #{@report.event.name}." }
  before_action(except: [:invitation, :reminder, :review_requested]) { @delivery_reason = "you submitted a reimbursement report for #{@report.event.name}." }

  def invitation
    mail to: @report.user.email_address_with_name, subject: "Get reimbursed by #{@report.event.name} for #{@report.name}", from: hcb_email_with_name_of(@report.event), reply_to: @report.user == @report.inviter ? nil : @report.inviter&.email_address_with_name
  end

  def reimbursement_approved
    mail to: @report.user.email_address_with_name, subject: "[Reimbursements] Approved: #{@report.name}", from: hcb_email_with_name_of(@report.event)
  end

  def rejected
    mail to: @report.user.email_address_with_name, subject: "[Reimbursements] Rejected: #{@report.name}", from: hcb_email_with_name_of(@report.event)
  end

  def reminder
    mail to: @report.user.email_address_with_name, subject: "[Reimbursements] Reminder: submit #{@report.name} for review", from: hcb_email_with_name_of(@report.event)
  end

  def review_requested
    @delivery_reason = "you are a manager on #{@report.event.name}."

    if @report.reviewer.present?
      mail to: @report.reviewer.email_address_with_name, subject: "[Reimbursements / #{@report.event.name}] Your Review Was Requested: #{@report.name}"
    else
      to = User.find(@report.event.organizer_positions.manager.pluck(:user_id)).excluding(@report.user).map(&:email_address_with_name)
      to << @report.event.config.contact_email if @report.event.config.contact_email.present?
      mail to:, subject: "[Reimbursements / #{@report.event.name}] Review Requested: #{@report.name}"
    end
  end

  def ach_failed
    @reason = params[:reason]

    mail subject: "[Reimbursements] ACH transfer for #{@report.name} failed to send", to: @report.user.email_address_with_name
  end

  def wire_failed
    @reason = params[:reason]

    mail subject: "[Reimbursements] Wire transfer for #{@report.name} failed to send", to: @report.user.email_address_with_name
  end

  def paypal_transfer_failed
    mail subject: "[Reimbursements] PayPal transfer for #{@report.name} failed to send", to: @report.user.email_address_with_name
  end

  def check_failed
    @reason = params[:reason]

    mail subject: "[Reimbursements] Mailed check for #{@report.name} failed to send", to: @report.user.email_address_with_name
  end

  def expenses_approved
    @expenses = params[:expenses]

    mail subject: "[Reimbursements] Expenses approved for #{@report.name}", to: @report.user.email_address_with_name
  end

end
