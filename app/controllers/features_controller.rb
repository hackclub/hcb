# frozen_string_literal: true

class FeaturesController < ApplicationController
  FEATURES = { # the keys are current feature flags, the values are emojis that show when-enabled.
    hcb_code_popovers_2023_06_16: nil,
    transactions_background_2024_06_05: %w[🌈 🔴 🟢],
    sudo_mode_2015_07_21: %w[🔐 🔒 🔑 🔓]
  }.freeze

  before_action :set_actor_and_feature

  def enable_feature
    if FEATURES.key?(@feature.to_sym) || admin_signed_in?
      if Flipper.enable_actor(@feature, @actor)
        confetti!(emojis: FEATURES[@feature.to_sym])
        flash[:success] = "You've opted into this beta; let us know if you have any feedback."
      else
        flash[:error] = "Error while opting into this beta. Please contact us or try again."
      end
    else
      flash[:error] = "Sorry, this feature flag doesn't currently exist."
    end

    redirect_to(actor_features_index(@actor))
  end

  def disable_feature
    if @feature == "sudo_mode_2015_07_21"
      return unless enforce_sudo_mode # rubocop:disable Style/SoleNestedConditional
    end

    if FEATURES.key?(@feature.to_sym) || admin_signed_in?
      if Flipper.disable_actor(@feature, @actor)
        flash[:success] = "You've opted out of this beta; please let us know if you had any feedback."
      else
        flash[:error] = "Error while opting out of this beta. Please contact us or try again."
      end
    else
      flash[:error] = "Sorry, this feature flag doesn't currently exist."
    end

    redirect_to(actor_features_index(@actor))
  end

  private

  def set_actor_and_feature
    if params[:event_id]
      @actor = Event.find(params[:event_id])
    elsif params[:user_id]
      @actor = User.find(params[:user_id])
    else
      @actor = current_user
    end
    @feature = params[:feature]
    authorize @actor
  end

  def actor_features_index(actor)
    case actor
    when Event
      edit_event_path(actor, tab: :features)
    when User
      if actor == current_user
        settings_previews_path
      else
        previews_user_path(actor)
      end
    else
      root_path
    end
  end

end
