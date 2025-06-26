# frozen_string_literal: true

class VercelController < ActionController::Base
  protect_from_forgery except: :webhook

  def webhook
    # fix this
    # put in env
    conn = Faraday.new(url: Rails.env.development? ? "https://hcbengr.my.hackclub.app" : "https://blog.hcb.hackclub.com") do |builder|
      builder.response :json
    end

    response = conn.get("/api/all-posts")

    Rails.logger.info response.body

    response.body.each do |post|
      BlogPost.where(slug: post["slug"], published_at: post["date"]).first_or_create
    end
  rescue => e
    Rails.logger.error e
  end

end
