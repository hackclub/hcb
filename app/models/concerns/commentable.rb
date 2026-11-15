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

  # The record this one shares a transaction with in the other transaction
  # engine (an HcbCode's Ledger::Item and vice versa). While comments move from
  # HCB codes to ledger items (#14105) they can be on either, so both sides
  # read the union. Nil once a record has no counterpart.
  def comment_counterpart
    nil
  end

  # Comments on this record and its counterpart, but not those shared with the
  # other side of a transfer: the set that decides who a comment notifies.
  def unshared_comments
    Comment.where(commentable: [self, comment_counterpart].compact).order(:created_at)
  end

  # Everything shown on this record's page
  def all_comments
    Comment.where(commentable: [self, comment_counterpart, shared_commentable].compact).order(:created_at)
  end
end
