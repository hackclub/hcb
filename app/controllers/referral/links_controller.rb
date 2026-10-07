# frozen_string_literal: true

module Referral
  class LinksController < ApplicationController
    skip_before_action :signed_in_user, only: :show

    def show
      @link = Referral::Link.find_by(slug: params[:id]).presence

      if @link
        authorize @link

        # An anonymous visitor needs a session for the attribution to hang off
        # of, so it can be bound to a user once they sign up. This is the only
        # place that creates one; every other reader of an anonymous session
        # only cares about a session a referral click already created.
        #
        # Created only once the link is known to be real, so bogus slugs don't
        # mint throwaway sessions.
        ensure_created_session

        Rails.error.handle do
          Referral::Attribution.create!(user: current_user, user_session: current_session, program: @link.program, link: @link)
        end

        # This is only configurable by admins
        redirect_to @link.program.redirect_to.presence || root_path, allow_other_host: true
      else
        skip_authorization

        redirect_to params[:return_to] || root_path
      end
    end

    def create
      program = Referral::Program.find(params[:program_id])
      @link = program.links.new(name: params[:name], slug: params[:slug].presence, creator: current_user)

      authorize(@link)

      if @link.save
        flash[:success] = "Referral link created successfully."
      else
        flash[:error] = @link.errors.full_messages.to_sentence
      end

      redirect_to referral_programs_admin_index_path
    end

  end
end
