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
end
