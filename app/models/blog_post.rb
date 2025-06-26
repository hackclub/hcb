# frozen_string_literal: true

# == Schema Information
#
# Table name: blog_posts
#
#  id           :bigint           not null, primary key
#  preview      :string
#  published_at :datetime
#  slug         :string
#  tags         :string
#  title        :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class BlogPost < ApplicationRecord
  # This model is populated from an API endpoint on blog.hcb.hackclub.com every time the blog is deployed on Vercel
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
