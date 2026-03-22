# frozen_string_literal: true

# == Schema Information
#
# Table name: discord_messages
#
#  id                 :bigint           not null, primary key
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  activity_id        :bigint
#  discord_channel_id :string           not null
#  discord_guild_id   :string           not null
#  discord_message_id :string           not null
#
# Indexes
#
#  index_discord_messages_on_activity_id         (activity_id)
#  index_discord_messages_on_discord_message_id  (discord_message_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (activity_id => activities.id)
#
module Discord
  class Message < ApplicationRecord
    belongs_to :activity, class_name: "PublicActivity::Activity", inverse_of: :discord_message, optional: true

    validates :discord_message_id, presence: true
    validates :discord_channel_id, presence: true
    validates :discord_guild_id, presence: true

  end
end
