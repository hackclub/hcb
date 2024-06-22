# frozen_string_literal: true

# == Schema Information
#
# Table name: comments
#
#  id                 :bigint           not null, primary key
#  action             :integer          default("commented"), not null
#  admin_only         :boolean          default(FALSE), not null
#  commentable_type   :string
#  content_ciphertext :text
#  has_untracked_edit :boolean          default(FALSE), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  commentable_id     :bigint
#  user_id            :bigint
#
# Indexes
#
#  index_comments_on_commentable_id_and_commentable_type  (commentable_id,commentable_type)
#  index_comments_on_commentable_type_and_commentable_id  (commentable_type,commentable_id)
#  index_comments_on_user_id                              (user_id)
#
class Comment < ApplicationRecord
  include Hashid::Rails
  include PublicIdentifiable

  set_public_id_prefix :cmt

  belongs_to :commentable, polymorphic: true
  belongs_to :user

  has_one_attached :file

  has_paper_trail skip: [:content] # ciphertext columns will still be tracked
  has_encrypted :content

  validates :user, presence: true
  validates :content, presence: true, unless: :has_attached_file?

  validate :commentable_includes_concern

  scope :admin_only, -> { where(admin_only: true) }
  scope :not_admin_only, -> { where(admin_only: false) }
  scope :edited, -> { joins(:versions).where("has_untracked_edit IS TRUE OR versions.event = 'update' OR versions.event = 'destroy'") }
  scope :has_attached_file, -> { joins(:file_attachment) }

  enum action: {
    commented: 0,
    changes_requested: 1 # used by reimbursements
  }

  include PublicActivity::Model
  tracked owner: proc{ |controller, record| controller&.current_user }, event_id: proc { |controller, record| record.admin_only? ? nil : record.commentable.try(:event)&.id }, only: [:create, :update]

  after_create_commit :send_notification_email

  broadcasts_refreshes_to ->(comment) { [comment.commentable, :comments] } unless Rails.env.test?

  def edited?
    has_untracked_edit? or
      versions.where("event = 'update' OR event = 'destroy'").any?
  end

  def has_attached_file?
    file.attached?
  end

  def action_text
    return "requested changes" if changes_requested?

    return "commented"
  end

  # This regex was stolen from URI::MailTo::EMAIL_REGEXP
  USER_MENTION_REGEX = /@([a-zA-Z0-9.!\#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)/

  def mentioned_users
    emails = content.scan(USER_MENTION_REGEX).flatten
    User.where(email: emails)
  end

  private

  def commentable_includes_concern
    unless commentable.class.included_modules.include?(Commentable)
      errors.add(:commentable_type, "is not commentable")
    end
  end

  def send_notification_email
    CommentMailer.with(comment: self).notification.deliver_later
  end

end
