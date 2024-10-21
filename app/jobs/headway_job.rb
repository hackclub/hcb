# frozen_string_literal: true

class HeadwayJob < ApplicationJob
  queue_as :low

  def perform
    connection = Faraday.new(url: "https://headwayapp.co") do |c|
      c.request :url_encoded
      c.response :json
    end

    response = connection.post do |req|
      req.url "/_/graphql/changelogs"
      req.headers["Content-Type"] = "application/json"
      req.headers["Cookie"] = Rails.application.credentials.headway.cookie
      req.headers["X-Csrf-Token"] = Rails.application.credentials.headway.csrf_token
      req.body = JSON.generate({ account: "7z8ovy" })
    end

    was_new_post = false

    response.body["data"]["changelogs"]["collection"].each do |post|
      categories = post["categories"].map { |x| x["name"] }
      next unless categories.include?("New")

      headway_id = post["id"].to_i

      # Make sure the images display correctly
      markdown = post["markdown"].gsub(/\.png\s*=\d{1,3}%\)/, ".png)")

      # Remove the tag from the top
      markdown = markdown.split("\n\n")
      markdown.shift
      markdown = markdown.join("\n\n")

      ChangelogPost.transaction do
        existing_post = ChangelogPost.find_by(headway_id:)
        if existing_post
          # Update existing post if title or markdown has changed
          if existing_post.title != post["title"] || existing_post.markdown != markdown
            existing_post.update!(
              title: post["title"],
              markdown:,
            )
          end
        else
          # Create new post
          ChangelogPost.create!(
            title: post["title"],
            headway_id:,
            markdown:,
            published_at: post["date"].to_datetime
          )
          was_new_post = true
        end
      end
    end

    Flipper.disable(:native_changelog_2024_07_03) if was_new_post
  end

end
