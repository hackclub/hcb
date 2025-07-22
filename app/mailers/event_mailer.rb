# frozen_string_literal: true

class EventMailer < ApplicationMailer
  before_action { @event = params[:event] }
  before_action { @emails = @event.organizer_contact_emails }

  def monthly_donation_summary
    @donations = @event.donations.where(aasm_state: [:in_transit, :deposited], created_at: Time.now.last_month.beginning_of_month..).order(:created_at)

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

end
