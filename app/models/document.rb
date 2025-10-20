# frozen_string_literal: true

# == Schema Information
#
# Table name: documents
#
#  id             :bigint           not null, primary key
#  aasm_state     :string
#  archived_at    :datetime
#  category       :integer          default("general"), not null
#  deleted_at     :datetime
#  name           :text
#  slug           :text
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  archived_by_id :bigint
#  event_id       :bigint
#  user_id        :bigint
#
# Indexes
#
#  index_documents_on_archived_by_id  (archived_by_id)
#  index_documents_on_event_id        (event_id)
#  index_documents_on_slug            (slug) UNIQUE
#  index_documents_on_user_id         (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (archived_by_id => users.id)
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (user_id => users.id)
#
class Document < ApplicationRecord
  include FriendlyId
  include AASM
  acts_as_paranoid

  friendly_id :slug_text, use: :slugged

  belongs_to :event, optional: true
  belongs_to :user
  belongs_to :archived_by, class_name: "User", optional: true

  has_one_attached :file
  validates :file, size: { less_than_or_equal_to: 25.megabytes }, if: -> { attachment_changes["file"].present? }

  has_many :downloads, class_name: "DocumentDownload", dependent: :destroy

  validates_presence_of :user, :name
  validate :ensure_file_attached

  scope :common, -> { where(event_id: nil) }

  enum :category, {
    general: 0,
    nonprofit_status: 1,
    tax_exemption: 2,
    forms: 3
  }

  aasm timestamps: true do
    state :active, initial: true
    state :archived, before_exit: -> do
      self.archived_by = nil
      self.archived_at = nil
    end

    event :mark_archive do
      transitions from: :active, to: :archived
      after do |archived_by = nil|
        update!(archived_by:) if archived_by.present?
      end

    end

    event :mark_unarchive do
      transitions from: :archived, to: :active
    end
  end

  def preview_url(resize: "500x500")
    return nil unless file
    return nil unless file.previewable?

    file.preview(resize:)
  end

  def common?
    event_id.nil?
  end

  private

  # ActiveStorage doesn't yet support attachment validation (how dumb... see
  # https://github.com/rails/rails/issues/31656). This manually checks if a
  # file is attached for the time being.
  def ensure_file_attached
    errors.add(:file, "must be attached") unless file.attached?
  end

  def slug_text
    "#{self.event ? self.event.name : 'common'} #{self.name}"
  end

end
