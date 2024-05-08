# frozen_string_literal: true

class FeaturesController < ApplicationController
  FEATURES = { # the keys are current feature flags, the values are emojis that show when-enabled.
    receipt_bin_2023_04_07: %w[🧾 🗑️ 💰],
    sms_receipt_notifications_2022_11_23: %w[📱 🧾 🔔 💬],
    hcb_code_popovers_2023_06_16: nil,
    rename_on_homepage_2023_12_06: %w[🖊️ ⚡ ⌨️],
    command_bar_2024_02_05: %w[🔍 🔎 ✨ 💸],
    transaction_tags_2022_07_29: %w[🏷️],
    user_permissions_2024_03_09: %w[📛 🧑‍💼 🪪 🎉],
    anonymous_donations_2024_01_29: %w[🫂 💳 🤑]
  }.freeze

  def enable_feature
    actor = params[:event_id] ? Event.find(params[:event_id]) : current_user
    feature = params[:feature]
    authorize actor
    if FEATURES.key?(feature.to_sym) || current_user.admin?
      if Flipper.enable_actor(feature, actor)
        confetti!(emojis: FEATURES[feature.to_sym])
        flash[:success] = "You've opted into this beta; let us know if you have any feedback."
      else
        flash[:error] = "Error while opting into this beta. Please contact us or try again."
      end
    else
      flash[:error] = "Sorry, this feature flag doesn't currently exist."
    end
    redirect_back fallback_location: actor
  end

  def disable_feature
    actor = params[:event_id] ? Event.find(params[:event_id]) : current_user
    feature = params[:feature]
    authorize actor
    if FEATURES.key?(feature.to_sym) || current_user.admin?
      if Flipper.disable_actor(feature, actor)
        # If it's the user permissions feature, make all the users & invites in the org managers.
        if feature == "user_permissions_2024_03_09" && actor.is_a?(Event)
          actor.organizer_positions.update_all(role: :manager)
          actor.organizer_position_invites.pending.update_all(role: :manager)
        end
        flash[:success] = "You've opted out of this beta; please let us know if you had any feedback."
      else
        flash[:error] = "Error while opting out of this beta. Please contact us or try again."
      end
    else
      flash[:error] = "Sorry, this feature flag doesn't currently exist."
    end
    redirect_back fallback_location: actor
  end

end
