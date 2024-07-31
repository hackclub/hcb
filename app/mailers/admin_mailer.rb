# frozen_string_literal: true

class AdminMailer < ApplicationMailer
  include Rails.application.routes.url_helpers

  def opdr_notification
    @opdr = params[:opdr]

    mail to:, subject: "[OPDR] #{@opdr.event.name} / #{@opdr.organizer_position.user.name}"
  end

  def reminders
    @tasks = []

    OrganizerPositionDeletionRequest.under_review.find_each do |opdr|
      if opdr.created_at < 24.hours.ago
        next if opdr.comments.any? { |c| c.user.admin? }

        @tasks << {
          url: organizer_position_deletion_requests_url(opdr),
          label: "[OPDR] #{opdr.organizer_position.user.name} (#{opdr.event.name}) (Requested by #{opdr.submitted_by.name})"
        }
      end
    end

    AchTransfer.pending.find_each do |ach|
      if ach.created_at < 24.hours.ago
        next if ach.comments.any? { |c| c.user.admin? } || ach.local_hcb_code.comments.any? { |c| c.user.admin? }

        @tasks << {
          url: ach_start_approval_admin_url(ach),
          label: "[ACH] #{ApplicationController.helpers.render_money ach.amount} #{ach.payment_for} (#{ach.event.name}) (Requested by #{ach.creator&.name || "Unknown User"})"
        }
      end
    end

    IncreaseCheck.pending.find_each do |check|
      if check.created_at < 24.hours.ago
        next if check.local_hcb_code.comments.any? { |c| c.user.admin? }

        @tasks << {
          url: increase_check_process_admin_url(check),
          label: "[Check] #{ApplicationController.helpers.render_money check.amount} #{check.payment_for} (#{check.event.name}) (Requested by #{check.user&.name || "Unknown User"})"
        }
      end
    end

    Reimbursement::Report.reimbursement_requested.find_each do |report|
      if report.reimbursement_requested_at < 24.hours.ago
        next if report.comments.any? { |c| c.user.admin? }

        @tasks << {
          url: reimbursement_report_url(report),
          label: "[Reimbursement::Report] #{ApplicationController.helpers.render_money report.amount} #{report.name} (#{report.event.name}) (Requested by #{report.user.name})"
        }
      end
    end

    Disbursement.reviewing.find_each do |disbursement|
      if disbursement.created_at < 24.hours.ago
        next if disbursement.comments.any? { |c| c.user.admin? } || disbursement.local_hcb_code.comments.any? { |c| c.user.admin? }

        @tasks << {
          url: disbursement_process_admin_url(disbursement),
          label: "[Disbursement] #{ApplicationController.helpers.render_money disbursement.amount} #{disbursement.name} (#{disbursement.source_event.name} to #{disbursement.destination_event.name}) (Requested by #{disbursement.requested_by&.name || "Unknown User"})"
        }
      end
    end

    return if @tasks.none?

    mail to:, subject: "24 Hour Reminders for the Operations Team"
  end

  private

  def to
    "hcb-promotions-aaaafacn32rulnb3zkd3h75afm@hackclub.slack.com"
  end

end
