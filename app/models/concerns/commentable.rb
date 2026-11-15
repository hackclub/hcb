# frozen_string_literal: true

module Commentable
  extend ActiveSupport::Concern
  included do
    has_many :comments, -> { order(:created_at) }, as: :commentable, inverse_of: :commentable
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

  # Everything shown on this record's page
  def all_comments
    Comment.where(commentable: [self, shared_commentable].compact).order(:created_at)
  end
end
