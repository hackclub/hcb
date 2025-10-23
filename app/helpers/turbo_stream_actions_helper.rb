# frozen_string_literal: true

module TurboStreamActionsHelper
  def refresh_link_modals
    turbo_stream_action_tag :refresh_link_modals
  end

  def refresh_suggested_pairings
    turbo_stream_action_tag :refresh_suggested_pairings
  end

  def close_modal
    turbo_stream_action_tag :close_modal
  end
end

Turbo::Streams::TagBuilder.prepend(TurboStreamActionsHelper)
