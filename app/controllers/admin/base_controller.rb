# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    skip_after_action :verify_authorized # do not force pundit
    before_action :signed_in_admin

    layout "admin"

  end
end
