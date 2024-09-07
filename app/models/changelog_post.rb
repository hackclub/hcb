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

end
