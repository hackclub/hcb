# frozen_string_literal: true

class CommentMailer < ApplicationMailer
  def notification
    @comment = params[:comment]
    return if @comment.nil?

    # the comment may have been soft-deleted (acts_as_paranoid) between this
    # job being enqueued and running - the in-memory `@comment` above still
    # looks valid since it was resolved before that happened, so re-check
    # against the DB rather than trusting it. There's nothing worth notifying
    # about for a comment that's already gone.
    return unless Comment.exists?(@comment.id)

    @commentable = @comment.commentable

    return if @commentable.comment_recipients_for(@comment).empty?

    # the bank@hackclub.com is used for automated comments,
    # for now, these automated comments won't notify users.
    # see OneTimeJobs::BackfillLostReceipts for an example
    # - @sampoder
    return if @comment.user == User.system_user

    return unless @comment.content || @comment.file

    mail_settings = {
      bcc: @commentable.comment_recipients_for(@comment),
      reply_to: "comments+#{@comment.public_id}@hcb.hackclub.com",
      subject: @commentable.comment_mailer_subject,
      template_path: "comment_mailer/#{@commentable.class.name.underscore}",
      from: email_address_with_name("hcb@hackclub.com", "#{@comment.user.name} via HCB")
    }.merge(headers)

    mail(mail_settings)
  end

  def bounce_missing_comment
    mail subject: @inbound_mail&.mail&.subject || "Unknown comment", to: @inbound_mail&.mail&.from&.first
  end

  private

  def headers
    {
      in_reply_to: thread_id(@commentable),
      message_id: message_id(@comment),
      references: @commentable.comments.map { |c| message_id(c) }.join(" ")
    }.compact_blank
  end

  def message_id(comment)
    # "<comment-cmt_Sl3ns3@hcb.hackclub.com>"
    "<comment-#{comment.public_id}@hcb.hackclub.com>"
  end

  def thread_id(commentable)
    first_comment = commentable.comments.first
    return unless first_comment

    message_id(first_comment)
  end

end
