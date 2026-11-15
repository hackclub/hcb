# frozen_string_literal: true

class CommentMailerPreview < ActionMailer::Preview
  def hcb_code_notification
    commentable = HcbCode.joins(:comments).order("comments.created_at DESC").first
    comment = commentable.comments.last
    CommentMailer.with(comment:,).notification
  end

  def ledger_item_notification
    commentable = Ledger::Item.joins(:comments).order("comments.created_at DESC").first
    comment = commentable.comments.last
    CommentMailer.with(comment:,).notification
  end

  def reimbursement_report_notification
    commentable = Reimbursement::Report.joins(:comments).order("comments.created_at DESC").first
    comment = commentable.comments.last
    CommentMailer.with(comment:,).notification
  end


end
