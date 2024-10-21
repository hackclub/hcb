# frozen_string_literal: true

class DonationMailerPreview < ActionMailer::Preview
  def donor_receipt
    @donation = Donation.deposited.last
    DonationMailer.with(donation: @donation).donor_receipt
  end

  def first_donation_notification
    @donation = Donation.deposited.last
    DonationMailer.with(donation: @donation).first_donation_notification
  end

  def donation_notification
    @donation = Donation.deposited.last
    DonationMailer.with(donation: @donation).donation_notification
  end

end
