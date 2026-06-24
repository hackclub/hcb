# frozen_string_literal: true

class EventMailer < ApplicationMailer
  before_action { @event = params[:event] }
  before_action :set_emails, except: [:monthly_donation_summary, :monthly_follower_summary, :subevent_created]
  before_action :set_whodunnit, only: [:transparency_mode_enabled, :transparency_mode_disabled, :monthly_announcements_enabled, :monthly_announcements_disabled]

  def monthly_donation_summary
    @donations = @event.donations.succeeded_and_not_refunded.where(created_at: Time.now.last_month.beginning_of_month..).order(:created_at)
    return if @donations.none?

    @emails = @event.organizer_contact_emails { |users| users.where(monthly_donation_summary: true) }
    return if @emails.none?

    @total = @donations.sum(:amount)

    @goal = @event.donation_goal
    @percentage = (@goal.progress_amount_cents.to_f / @goal.amount_cents) if @goal.present?

    mail to: @emails, subject: "#{@event.name} received #{@donations.length} #{"donation".pluralize(@donations.length)} this past month"
  end

  def monthly_follower_summary
    @follows = @event.event_follows.where(created_at: Time.now.last_month.beginning_of_month..).order(:created_at)
    return if @follows.none?

    @emails = @event.organizer_contact_emails { |users| users.where(monthly_follower_summary: true) }
    return if @emails.none?

    @total = @follows.length

    mail to: @emails, subject: "#{@event.name} got #{@total} #{"follower".pluralize(@total)} this past month"
  end

  def donation_goal_reached
    @goal = @event.donation_goal
    @donations = @event.donations.succeeded.where(created_at: @goal.tracking_since..)

    @announcement = Announcement::Templates::DonationGoalReached.new(
      event: @event,
      author: User.system_user
    ).create

    mail to: @emails, subject: "#{@event.name} has reached its donation goal!"
  end

  def negative_balance
    @balance = params.fetch(:balance)

    mail(to: @emails, subject: "#{@event.name} has a negative balance")
  end

  def user_call_requested
    @user = params[:user]

    mail to: @user.email_address_with_name,
         subject: "We've received your request for an onboarding call for #{@event.name}"
  end

  def ops_call_requested
    @requesting_user = params[:requesting_user]

    mail to: OPERATIONS_EMAIL,
         subject: "#{@requesting_user.name} is requesting an onboarding call for #{@event.name} #{"with #{@event.point_of_contact.name}" if @event.point_of_contact.present?}"
  end

  def transparency_mode_enabled
    @can_disable_transparency = @event.eligible_for_disabling_transparency?
    mail to: @emails, subject: "#{@event.name} has enabled transparency mode"
  end

  def transparency_mode_disabled
    @can_enable_transparency = @event.eligible_for_transparency?
    @visible_pages = []
    @visible_pages << { name: "donation page", link: start_donation_donations_url(@event) } if @event.donation_page_available?
    @visible_pages << { name: "public reimbursements page", link: reimbursement_start_reimbursement_report_url(@event) } if @event.public_reimbursement_page_enabled?
    @visible_pages << { name: "announcements page", link: event_announcement_overview_url(@event) } if @event.announcements.published.any?

    mail to: @emails, subject: "#{@event.name} has disabled transparency mode"
  end

  def monthly_announcements_enabled
    @monthly_announcement = @event.announcements.monthly_for(Date.today).last
    @scheduled_for = Date.today.next_month.beginning_of_month
    @warning_date = @scheduled_for - 7.days

    mail to: @emails, subject: "#{@event.name} has enabled monthly announcements"
  end

  def monthly_announcements_disabled
    mail to: @emails, subject: "#{@event.name} has disabled monthly announcements"
  end

  def subevent_created
    @subevent = params[:subevent]
    @creator = params[:creator]
    @emails = @event.organizer_contact_emails(only_managers: true)
    return if @emails.none?

    mail to: @emails, subject: "[#{@event.name}] #{@creator.name} created #{@subevent.name}, a new sub-organization under #{@event.name}"
  end

  private

  def set_emails
    @emails = @event.organizer_contact_emails
  end

  def set_whodunnit
    @whodunnit = params[:whodunnit]

    # Not using role_at_least? because we want this to be false for HCB admins
    @is_manager = @event.ancestor_organizer_positions.map(&:user).include?(@whodunnit)
  end

end
