# frozen_string_literal: true

# == Schema Information
#
# Table name: changelog_posts
#
#  id           :bigint           not null, primary key
#  markdown     :string
#  published_at :datetime
#  title        :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  headway_id   :integer
#
class ChangelogPost < ApplicationRecord
  def self.latest
    order(published_at: :desc).first
  end

  has_and_belongs_to_many :viewers, class_name: "User"

  def viewed_by?(user)
    viewers.include?(user)
  end

  def mark_viewed_by!(user)
    begin
      viewers << user
    rescue ActiveRecord::RecordNotUnique
      # This can happen when loading two pages at the same time and a race condition occurs.
      # We can just ignore it to avoid crashing the slower page.
    end
  end

end
