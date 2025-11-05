# frozen_string_literal: true

class EventMailer < ApplicationMailer
  before_action { @event = params[:event] }
  before_action { @emails = @event.organizer_contact_emails }

  def monthly_donation_summary
    @donations = @event.donations.succeeded_and_not_refunded.where(created_at: Time.now.last_month.beginning_of_month..).order(:created_at)

    return if @donations.none?
    return if @emails.none?

    @total = @donations.sum(:amount)

    @goal = @event.donation_goal
    @percentage = (@goal.progress_amount_cents.to_f / @goal.amount_cents) if @goal.present?

    mail to: @emails, subject: "#{@event.name} received #{@donations.length} #{"donation".pluralize(@donations.length)} this past month"
  end

  def monthly_follower_summary
    @follows = @event.event_follows.where(created_at: Time.now.last_month.beginning_of_month..).order(:created_at)

    return if @follows.none?
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

  def transparency_mode_enabled
    @whodunnit = params[:whodunnit]
    mail to: @emails, subject: "#{@event.name} has enabled transparency mode"
  end

  def transparency_mode_disabled
    @whodunnit = params[:whodunnit]
    mail to: @emails, subject: "#{@event.name} has disabled transparency mode"
  end

  def monthly_announcements_enabled
    @whodunnit = params[:whodunnit]
    @monthly_announcement = @event.announcements.monthly_for(Date.today).last
    @scheduled_for = Date.today.next_month.beginning_of_month
    @warning_date = @scheduled_for - 7.days

    mail to: @emails, subject: "#{@event.name} has enabled monthly announcements"
  end

  def monthly_announcements_disabled
    @whodunnit = params[:whodunnit]
    mail to: @emails, subject: "#{@event.name} has disabled monthly announcements"
  end

end
