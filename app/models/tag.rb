# frozen_string_literal: true

# == Schema Information
#
# Table name: tags
#
#  id          :bigint           not null, primary key
#  color       :text
#  emoji       :string           not null
#  label       :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  tag_list_id :bigint           not null
#
# Indexes
#
#  index_tags_on_event_id     (event_id)
#  index_tags_on_tag_list_id  (tag_list_id)
#
# Foreign Keys
#
#  fk_rails_...  (tag_list_id => tag_lists.id)
#
class Tag < ApplicationRecord
  include ActionView::Helpers::TextHelper # for `pluralize`

  include Hashid::Rails
  hashid_config salt: ""

  include PublicIdentifiable
  set_public_id_prefix :tag

  # Tags belonged to an event until they moved onto tag lists
  # (https://github.com/hackclub/hcb/issues/15708). The column is dropped in a
  # follow-up once the migration has shipped.
  self.ignored_columns += ["event_id"]

  belongs_to :tag_list
  # The event whose ledger owns the list; see TagList#event.
  has_one :event, through: :tag_list
  # Legacy rows; tags now live on ledger items (see ledger_item_tags).
  # hcb_codes_tags has no foreign key, so without this a deleted tag orphans
  # them. delete_all, not destroy: HcbCodeTag's broadcast callbacks render
  # partials that now expect a ledger item.
  has_many :hcb_code_tags, dependent: :delete_all
  # Suggestions are no longer created, but hcb_code_tag_suggestions has a
  # foreign key to tags, so this stays until the table is dropped.
  has_many :hcb_code_tag_suggestions, dependent: :destroy, class_name: "HcbCode::Tag::Suggestion"
  has_many :hcb_codes, through: :hcb_code_tags
  has_many :ledger_item_tags, class_name: "Ledger::Item::Tag", dependent: :destroy
  has_many :ledger_items, through: :ledger_item_tags, class_name: "Ledger::Item"

  validates :label, presence: true, uniqueness: { scope: :tag_list_id, case_sensitive: false }
  validate :only_one_valid_emoji

  COLORS = %w[muted red orange yellow green cyan blue purple].freeze
  validates :color, inclusion: { in: COLORS }

  include PgSearch::Model
  pg_search_scope :search_label, against: :label

  def removal_confirmation_message
    message = "Are you sure you'd like to delete this tag?"

    if ledger_items.any?
      message + " It will be removed from #{pluralize(ledger_items.size, 'transaction')}."
    else
      message
    end
  end

  private

  def only_one_valid_emoji
    if !emoji.present? || (emoji.grapheme_clusters.size > 1 || !emoji.match?(/\A(\p{Emoji})/))
      errors.add(:emoji, "must be a single emoji")
    end
  end

end
