# frozen_string_literal: true

module Commentable
  extend ActiveSupport::Concern
  included do
    has_many :comments, as: :commentable
  end

  def comment_recipients_for(comment)
    []
  end

  def comment_mailer_subject
    "New comment from HCB"
  end

  def comment_mentionable(current_user: nil)
    []
  end

  # Override in models that share comments with another commentable
  def shared_commentable
    nil
  end

  def shared_commentable?
    shared_commentable.present?
  end

  def all_comments
    if shared_commentable
      Comment.where(commentable: self).or(Comment.where(commentable: shared_commentable))
    else
      comments
    end
  end
end
