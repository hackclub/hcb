# frozen_string_literal: true

module Admin
  class W9sController < ApplicationController
    skip_after_action :verify_authorized # do not force pundit
    before_action :signed_in_admin

    layout "admin"

    def index
      @page = params[:page] || 1
      @per = params[:per] || 20
      @w9s = W9.all.order(signed_at: :desc).page(@page).per(@per)
    end

    def new
    end

    def create
      @w9 = User.find_or_create_by(email: params[:email]).w9s.create(url: params[:url], signed_at: params[:signed_at], uploaded_by: current_user)
      redirect_to admin_w9s_path
    end

  end
end
