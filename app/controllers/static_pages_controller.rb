# frozen_string_literal: true

require "net/http"

class StaticPagesController < ApplicationController
  skip_after_action :verify_authorized # do not force pundit
  skip_before_action :signed_in_user, only: [:mobile, :branding, :roles, :security]
  skip_before_action :redirect_to_onboarding, only: [:mobile, :branding, :roles, :security]

  after_action only: [:index, :branding, :security] do
    # Allow indexing home and branding pages
    response.delete_header("X-Robots-Tag")
  end

  def index
    if signed_in?
      @service = StaticPageService::Index.new(current_user:)

      @events = @service.events

      featured_event_ids = %w[org_MpJurQ org_Y0zun7 org_Y1ZuDz org_DyuReR org_Jounxy org_0zuXDP org_1Zu4Jr org_5Gu7Lo org_E1uGdn org_G3uq7b]

      @featured_events = featured_event_ids.map do |id|
        Event.find_by_public_id(id)
      end.select do |event|
        event&.is_public? && event.is_indexable?
      end.sample(6)

      @organizer_positions = @service.organizer_positions.not_hidden
      @invites = @service.invites
      @invite_requests = @service.invite_requests
      @applications = @service.applications

      if auditor_signed_in? && cookies[:admin_activities] == "everyone"
        @activities = PublicActivity::Activity.all.order(created_at: :desc).page(params[:page]).per(25)
      else
        @activities = PublicActivity::Activity.for_user(current_user).order(created_at: :desc).page(params[:page]).per(25)
      end

      @show_event_reorder_tip = current_user.organizer_positions.where.not(sort_index: nil).none?

      @hcb_expansion = Rails.cache.read("hcb_acronym_expansions")&.sample || "Hack Club Buckaroos"

    end
  end

  def admin_tools
    unless auditor_signed_in?
      redirect_to(root_path, flash: { error: "You are not authorized to visit this page." })
      return
    end

    @transaction_volume = CanonicalTransaction.included_in_stats.sum("abs(amount_cents)")
  end

  def mobile
    if request.user_agent&.match("iPhone")
      redirect_to "https://apps.apple.com/us/app/hcb-by-hack-club/id6465424810", allow_other_host: true
    elsif request.user_agent&.match("Android")
      redirect_to "https://play.google.com/store/apps/details?id=com.hackclub.hcb", allow_other_host: true
    else
      redirect_to "https://hackclub.com/hcb", allow_other_host: true
    end
  end

  def branding
    @logos = [
      { name: "Original Light", criteria: "For white or light colored backgrounds.", background: "smoke" },
      { name: "Original Dark", criteria: "For black or dark colored backgrounds.", background: "black" },
      { name: "Outlined Black", criteria: "For white or light colored backgrounds.", background: "snow" },
      { name: "Outlined White", criteria: "For black or dark colored backgrounds.", background: "black" }
    ]
    @icons = [
      { name: "Icon Original", criteria: "The original HCB logo.", background: "smoke" },
      { name: "Icon Dark", criteria: "HCB logo in dark mode.", background: "black" }
    ]
    @event_name = signed_in? && current_user.events.first&.name || "Hack Pennsylvania"
    @event_slug = signed_in? && current_user.events.first&.slug || "hack-pennsylvania"

    render layout: "docs"
  end

  def roles
    # Ironically, don't put prefaces at the start of a hash here.
    # (It'll erroneously offset the title padding top calculation.)
    @perms = {
      Team: {
        "Invite a user": :manager,
        "Request removal of a user": :manager,
        "Cancel invite made by another user": :manager,
        "Cancel invite made by yourself": :member,
        "Change another user's role": :manager,
      },
      Transfers: {
        Checks: {
          "Send a mailed check": :manager,
          "View a mailed check": :reader,
        },
        "Check deposits": {
          "Deposit a check": :member,
          "View a check deposit": :reader,
          "View images of a check deposit": :manager,
          _preface: "For depositing a check by taking a picture of it"
        },
        "ACH transfers": {
          "Send an ACH Transfer": :manager,
          "Cancel an ACH Transfer": :manager,
          "View an ACH Transfer": :reader,
          "View recipient's payment details": :manager,
        },
        "Account & routing numbers": {
          "View the organization's account & routing numbers": :manager
        },
        "HCB transfers": {
          "Create a HCB Transfer": :manager,
          "Cancel a HCB Transfer": :manager,
          "View a HCB Transfer": :reader
        },
        _preface: "As a general rule, only managers can create/modify financial transfers"
      },
      Cards: {
        "Order a card": :member,
        "Freeze/defrost your own card": :member,
        "Freeze/defrost another user's card": :manager,
        "Rename your own card": :member,
        "Rename another user's card": :manager,
        "View another user's card number": :manager,
        "View card expiration date": :reader,
        "View card billing address": :reader,
      },
      Reimbursements: {
        "Get reimbursed through HCB": :member,
        "View reimbursement reports": :reader,
        "Review, approve, and reject reports": :manager,
      },
      Announcements: {
        "Create or delete an announcement": :manager,
        "Publish an announcement": :manager,
        "View announcements": :reader,
        "View followers": :reader,
        "Remove followers": :manager
      },
      "Google Workspace": {
        "Create an account": :manager,
        "Suspend an account": :manager,
        "Reset an account's password": :manager,
      },
      Documents: {
        "View documents": :reader
      },
      "Settings": {
        "View settings": :reader,
        "Edit settings": :manager,
      }
    }

    render layout: "docs"
  end

  def security
    render layout: "docs"
  end

  def suggested_pairings
    render partial: "static_pages/suggested_pairings", locals: {
      pairings: current_user.receipt_bin.suggested_receipt_pairings,
      current_slide: 0
    }
  end

  def receipt
    if params[:file] # Ignore if no files were uploaded
      ::ReceiptService::Create.new(
        uploader: current_user,
        attachments: params[:file],
        upload_method: params[:upload_method]
      ).run!

      if params[:show_link]
        flash[:success] = { text: "#{"Receipt".pluralize(params[:file].length)} added!", link: hcb_code_path(@hcb_code), link_text: "View" }
      else
        flash[:success] = "#{"Receipt".pluralize(params[:file].length)} added!"
      end
    end

    return redirect_to params[:redirect_url] if params[:redirect_url]

    redirect_back

  rescue => e
    Rails.error.report(e)

    flash[:error] = e.message
    return redirect_to params[:redirect_url] if params[:redirect_url]

    redirect_back
  end

  def stripe_charge_lookup
    charge_id = params[:id]
    @payment = Invoice.find_by(stripe_charge_id: charge_id)

    # No invoice with that charge id? Maybe we can find a donation payment with that charge?
    # Donations don't store charge id, but they store payment intent, and we can link it with the charge's payment intent on stripe
    unless @payment
      payment_intent_id = StripeService::Charge.retrieve(charge_id)["payment_intent"]
      @payment = Donation.find_by(stripe_payment_intent_id: payment_intent_id)
    end

    @event = @payment.event

    render json: {
      event_id: @event.id,
      event_name: @event.name,
      payment_type: @payment.class.name,
      payment_id: @payment.id
    }
  rescue StripeService::InvalidRequestError => e
    render json: {
      event_id: nil
    }
  end

end
