# frozen_string_literal: true

module Users
  class FirstController < ApplicationController
    include UsersHelper

    skip_after_action :verify_authorized
    skip_before_action :signed_in_user
    invisible_captcha only: [:create], honeypot: :remember_me

    def index
      return redirect_to welcome_first_index_path unless signed_in?(allow_unverified: true)

      load_team_community

      @macbook_raffle = Raffle.find_by(user: current_user(allow_unverified: true), program: "first-worlds-2026-macbook")
      @printer_raffle = Raffle.find_by(user: current_user(allow_unverified: true), program: "first-worlds-2026-printer")
      @airpods_raffle = Raffle.find_by(user: current_user(allow_unverified: true), program: "first-worlds-2026-airpods")

      @advisor_email_body = <<~EMAIL
        At Championships this year, I met a couple of engineers from a nonprofit, Hack Club. They run a service called HCB and they pitch it as "the ultimate booster club for FRC, FTC, and FLL teams."

        The service includes non-profit status, debit cards, and online donations. It also makes it easier to receive grants.

        Here's a website with more information: https://hackclub.com/fiscal-sponsorship/first/. Seems like it'd be good fit for our team!
      EMAIL
    end

    def request_org_invite
      if Date.current >= Date.new(2026, 5, 3)
        redirect_to first_index_path, flash: { error: "This feature is no longer available." } and return
      end

      user = current_user(allow_unverified: true)
      event = Event::Affiliation.matching_first_event_for(user)

      unless Event::Affiliation.eligible_to_request_invite?(user, event)
        redirect_to first_index_path, flash: { error: "You're not eligible to request to join this organization." } and return
      end

      if event.organizer_position_invite_requests.pending.exists?(requester_id: user.id)
        redirect_to first_index_path, flash: { warning: "You already have a pending request." } and return
      end

      ActiveRecord::Base.transaction do
        # The link exists only to satisfy the Request → Link FK; it expires
        # immediately so it can't be reused as a join URL.
        link = event.organizer_position_invite_links.create!(creator: user, expires_in: 0)
        OrganizerPositionInvite::Request.create!(requester: user, link:)
      end

      redirect_to first_index_path, flash: { success: "Request sent! Your team member will review it." }
    end

    def team
      if ["ftc", "fll"].include?(params[:league])
        return render json: { error: "Team prefill is unsupported for #{params[:league]}" }, status: :not_found
      end

      result = Event::Affiliation.tba_lookup(params[:league], params[:team_number])

      if result.nil?
        return render json: { error: "Team not found" }, status: :not_found
      end

      render json: result
    end

    def sign_out
      helpers.sign_out

      redirect_to auth_users_path
    end

    def new
      return redirect_to first_index_path if signed_in?(allow_unverified: true)

      @referral_link_slug = Referral::Link.find_by(slug: params[:referral])&.slug if params[:referral].present?
      @user = User.new(affiliations: [Event::Affiliation.new])
    end

    def verify_email
      return redirect_to welcome_first_index_path unless current_user(allow_unverified: true)&.unverified?

      @login = Login.create!(state: { purpose: "first", return_to: first_index_path }, user: current_user(allow_unverified: true))

      cookies.signed["browser_token_#{@login.hashid}"] = { value: @login.browser_token, expires: Login::EXPIRATION.from_now }

      redirect_to choose_login_preference_login_path(@login)
    end

    def create
      program = nil
      program = "first-worlds-2026-macbook" if ["student_leader", "student_member"].include?(user_params.dig(:affiliations_attributes, "0", "role"))

      unless User.where(email: user_params[:email]).exists?
        @user = User.new(user_params)
        @user.creation_method = :first_robotics_form
        @user.save!

        Raffle.find_or_create_by!(user: @user, program:) if program.present?

        create_session(user: @user, verified: false)

        redirect_to first_index_path and return
      end

      @user = User.find_by!(email: user_params[:email])
      @login = Login.create!(state: { purpose: "first", return_to: first_index_path, user_params:, raffle: program }, user: @user)

      cookies.signed["browser_token_#{@login.hashid}"] = { value: @login.browser_token, expires: Login::EXPIRATION.from_now }

      redirect_to choose_login_preference_login_path(@login)
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = e.message

      render :new, status: :unprocessable_entity
    end

    private

    def user_params
      params.require(:user).permit(:email, :full_name, affiliations_attributes: [:league, :team_number, :name, :team_name, :role])
    end

    def load_team_community
      user = current_user(allow_unverified: true)
      affiliation = user&.affiliations&.find_by(name: "first")
      return unless affiliation && affiliation.league.present? && affiliation.team_number.present?

      @first_affiliation = affiliation
      @team_event = Event::Affiliation.matching_first_event_for(user)

      if @team_event
        positions_scope = @team_event.organizer_positions.where(deleted_at: nil).where.not(user_id: user.id)
        @team_org_members = positions_scope
                            .joins(:user)
                            .order(Arel.sql("users.verified DESC NULLS LAST, organizer_positions.role DESC, organizer_positions.created_at DESC"))
                            .limit(5)
                            .map(&:user)
        @team_org_members_total = positions_scope.count
      else
        peer_user_ids = Event::Affiliation
                        .where(affiliable_type: "User", name: "first")
                        .where("metadata ->> 'league' = ?", affiliation.league)
                        .where("metadata ->> 'team_number' = ?", affiliation.team_number)
                        .where.not(affiliable_id: user.id)
                        .pluck(:affiliable_id)

        @teammates = User
                     .where(id: peer_user_ids)
                     .order(Arel.sql("verified DESC NULLS LAST, created_at DESC"))
                     .limit(5)
                     .to_a
        @teammates_total = peer_user_ids.size
      end
    end

  end
end
