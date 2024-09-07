# frozen_string_literal: true

# == Schema Information
#
# Table name: comment_reactions
#
#  id         :bigint           not null, primary key
#  emoji      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  comment_id :bigint           not null
#  reactor_id :bigint           not null
#
# Indexes
#
#  index_comment_reactions_on_comment_id  (comment_id)
#  index_comment_reactions_on_emoji       (emoji)
#  index_comment_reactions_on_reactor_id  (reactor_id)
#
# Foreign Keys
#
#  fk_rails_...  (comment_id => comments.id)
#  fk_rails_...  (reactor_id => users.id)
#
class Comment
  class Reaction < ApplicationRecord
    belongs_to :comment
    belongs_to :reactor, class_name: "User"

    validates :emoji, presence: true
    validates :emoji, uniqueness: { scope: [:reactor_id, :comment_id], message: "has already been used for this comment" }

    EMOJIS = %w[👍 👎 😄 🎉 😔 ❤️ 🚀 👀 💀].freeze

    validates_inclusion_of :emoji, in: EMOJIS, on: :create

  end

end
