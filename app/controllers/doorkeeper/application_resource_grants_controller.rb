# frozen_string_literal: true

module Doorkeeper
  class ApplicationResourceGrantsController < ::ApplicationController
    layout "doorkeeper/admin"

    before_action :require_admin!
    before_action :set_application

    def index
      @grants = @application.resource_grants.order(:resource_type, :access_level)
      @known_resource_types = Doorkeeper::Application.scope_groups
                                                      .flat_map { |g| g[:scopes].filter_map { |s| s[:value].split(":", 2).first if s[:value].include?(":") } }
                                                      .uniq.sort
    end

    def create
      @application.resource_grants.create!(resource_grant_params)
      redirect_to oauth_application_resource_grants_path(@application), notice: "Grant added."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to oauth_application_resource_grants_path(@application), alert: e.record.errors.full_messages.to_sentence
    end

    def destroy
      @application.resource_grants.find(params[:id]).destroy!
      redirect_to oauth_application_resource_grants_path(@application), notice: "Grant removed."
    end

    private

    def set_application
      @application = Doorkeeper::Application.find(params[:application_id])
    end

    def require_admin!
      redirect_to root_path unless current_user&.admin?
    end

    def resource_grant_params
      params.require(:resource_grant).permit(:resource_type, :access_level, :scope_root_type, :scope_root_id)
    end
  end
end
