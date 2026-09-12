# frozen_string_literal: true

json.data @comments, partial: "api/v5/comments/comment", as: :comment
pagination_metadata(json)
