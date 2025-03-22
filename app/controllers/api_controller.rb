# frozen_string_literal: true

class ApiController < ApplicationController
  before_action :check_token, except: [:the_current_user]
  skip_before_action :verify_authenticity_token # do not use CSRF token checking for API routes
  skip_after_action :verify_authorized # do not force pundit
  skip_before_action :signed_in_user

  rescue_from(ActiveRecord::RecordNotFound) { render json: { error: "Record not found" }, status: :not_found }

  def the_current_user
    return head :not_found unless signed_in?

    render json: {
      avatar: helpers.profile_picture_for(current_user),
      name: current_user.name,
    }
  end

  def create_demo_event
    event = EventService::CreateDemoEvent.new(
      name: params[:name],
      email: params[:email],
      country: params[:country],
      postal_code: ValidatesZipcode.valid?(params[:postal_code], params[:country]) ? params[:postal_code] : nil,
      is_public: params[:transparent].nil? ? true : params[:transparent],
    ).run

    render json: {
      id: event.id,
      name: event.name,
      slug: event.slug,
      email: params[:email],
      transparent: event.is_public?,
    }
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    render json: { error: e }, status: :unprocessable_entity
  end

  def user_find
    user = User.find_by_email!(params[:email])
    recent_transactions = if user.stripe_cardholder.present?
                            RawPendingStripeTransaction.where("stripe_transaction->>'cardholder' = ?", user.stripe_cardholder.stripe_id)
                                                       .order(Arel.sql("stripe_transaction->>'created' DESC"))
                                                       .limit(10)
                                                       .includes(canonical_pending_transaction: [:canonical_pending_declined_mapping, :local_hcb_code])
                                                       .map do |t|
                                                         {
                                                           memo: t.memo,
                                                           date: t.date_posted,
                                                           declined: t.canonical_pending_transaction.declined?,
                                                           id: t.canonical_pending_transaction.local_hcb_code.hashid,
                                                           amount: t.amount_cents,
                                                         }
                                                       end
                          else
                            []
                          end

    render json: {
      name: user.name,
      email: user.email,
      slug: user.slug,
      id: user.id,
      orgs: user.events.not_hidden.map { |e| { name: e.name, slug: e.slug, demo: e.demo_mode?, balance: e.balance_available, service_level: e.service_level, point_of_contact: e.point_of_contact&.name || "none" } },
      card_count: user.stripe_cards.count,
      recent_transactions:,
      timezone: user.user_sessions.where.not(timezone: nil).order(created_at: :desc).first&.timezone,
    }
  end

  private

  def check_token
    authed = authenticate_with_http_token do |token|
      ActiveSupport::SecurityUtils.secure_compare(token, Credentials.fetch(:API_TOKEN))
    end

    render json: { error: "Unauthorized" }, status: :unauthorized unless authed
  end

end
