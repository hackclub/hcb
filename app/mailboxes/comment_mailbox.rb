# frozen_string_literal: true

require "email_reply_parser"

class CommentMailbox < ApplicationMailbox
  # mail --> Mail object, this actual email
  # inbound_email => ActionMailbox::InboundEmail record --> the active storage record

  include Pundit::Authorization
  include HasAttachments

  before_processing :set_user
  before_processing :set_comment
  before_processing :set_commentable
  before_processing do
    set_attachments(include_body: false)
  end

  def process
    return unless @user
    return unless @commentable
    return unless ensure_permissions?

    comment = @commentable.comments.build({
                                            content: EmailReplyParser.parse_reply(text || body),
                                            file: @attachments&.first,
                                            admin_only: @comment.admin_only,
                                            user: @user
                                          })

    comment.save
  end

  private

  def set_comment
    comment_public_id = mail.to.first.match(/\+(.*)@/i).captures.first
    @comment = Comment.find_by_public_id(comment_public_id)
  end

  def set_commentable
    @commentable = @comment.commentable
  end

  def set_user
    @user = User.find_by(email: mail.from[0])
  end

  def ensure_permissions?
    return false if @comment.nil?

    Pundit.policy(@user, @comment).new?
  end

end
