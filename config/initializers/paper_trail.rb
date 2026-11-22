# frozen_string_literal: true

# `versions.user_session_id` and `versions.api_token_id` are filled in by
# `info_for_paper_trail` in ApplicationController and Api::V4::ApplicationController.
# Neither has a foreign key: sessions and tokens are deleted independently of the
# audit trail, so these resolve to nil once the record is gone.
Rails.application.config.to_prepare do
  PaperTrail::Version.class_eval do
    belongs_to :user_session, class_name: "User::Session", optional: true
    belongs_to :api_token, optional: true
  end
end
