# frozen_string_literal: true

# == Schema Information
#
# Table name: tags
#
#  id         :bigint           not null, primary key
#  color      :text
#  emoji      :string
#  label      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  event_id   :bigint           not null
#
# Indexes
#
#  index_tags_on_event_id  (event_id)
#
class Tag < ApplicationRecord
  include ActionView::Helpers::TextHelper # for `pluralize`

  include PublicIdentifiable
  set_public_id_prefix :tag

  belongs_to :event
  has_many :hcb_code_tags
  has_many :hcb_code_tag_suggestions, dependent: :destroy, class_name: "HcbCode::Tag::Suggestion"
  has_many :hcb_codes, through: :hcb_code_tags

  validates :label, presence: true, uniqueness: { scope: :event_id, case_sensitive: false }
  validate :only_one_valid_emoji

  COLORS = %w[muted red orange yellow green cyan blue purple].freeze
  validates :color, inclusion: { in: COLORS }

  include PgSearch::Model
  pg_search_scope :search_label, against: :label

  def removal_confirmation_message
    message = "Are you sure you'd like to delete this tag?"

    if hcb_codes.size > 0
      message + " It will be removed from #{pluralize(hcb_codes.size, 'transaction')}."
    else
      message
    end
  end

  after_create_commit {
    SuggestTagsJob.perform_later(event_id: event.id)
  }

  private

  def only_one_valid_emoji
    if !emoji.present? || (emoji.grapheme_clusters.size > 1 || !emoji.match?(/\A(\p{Emoji})/))
      errors.add(:emoji, "must be a single emoji")
    end
  end

end
