# frozen_string_literal: true

require "net/http"

class StaticPagesController < ApplicationController
  skip_after_action :verify_authorized # do not force pundit
  skip_before_action :signed_in_user, only: [:branding, :roles, :security]
  skip_before_action :redirect_to_onboarding, only: [:branding, :roles, :security]

  after_action only: [:index, :branding, :security] do
    # Allow indexing home and branding pages
    response.delete_header("X-Robots-Tag")
  end

  def index
    if signed_in?
      @service = StaticPageService::Index.new(current_user:)

      @events = @service.events
      @organizer_positions = @service.organizer_positions.not_hidden
      @invites = @service.invites

      if admin_signed_in? && cookies[:admin_activities] == "everyone"
        @activities = PublicActivity::Activity.all.order(created_at: :desc).page(params[:page]).per(25)
      else
        @activities = PublicActivity::Activity.for_user(current_user).order(created_at: :desc).page(params[:page]).per(25)
      end

      @show_event_reorder_tip = current_user.organizer_positions.where.not(sort_index: nil).none?

      @hcb_expansion = Rails.cache.read("hcb_acronym_expansions")&.sample || "Hack Club Buckaroos"

    end
    if admin_signed_in?
      @transaction_volume = CanonicalTransaction.included_in_stats.sum("abs(amount_cents)")
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
          "View a mailed check": :member,
        },
        "Check Deposit": {
          "Deposit a check": :member,
          "View a check deposit": :member,
          "View images of a check deposit": :manager,
          _preface: "For depositing a check by taking a picture of it"
        },
        "ACH Transfers": {
          "Send an ACH Transfer": :manager,
          "Cancel an ACH Transfer": :manager,
          "View an ACH Transfer": :member,
          "View recipient's payment details": :manager,
        },
        "Account & Routing numbers": {
          "View the organization's account & routing numbers": :manager
        },
        "HCB Transfers": {
          "Create an HCB Transfer": :manager,
          "Cancel an HCB Transfer": :manager,
          "View an HCB Transfer": :member
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
        "View card expiration date": :member,
        "View card billing address": :member,
      },
      Reimbursements: {
        "Get reimbursed through HCB": :member,
        "View reimbursement reports": :member,
        "Review, approve, and reject reports": :manager,
      },
      "Google Workspace": {
        "Create an account": :manager,
        "Suspend an account": :manager,
        "Reset an account's password": :manager,
      },
      "Settings": {
        "View settings": :member,
        "Edit settings": :manager,
      }
    }
  end

  def security; end

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
