# frozen_string_literal: true

require "rails_helper"

RSpec.describe StripeEmailValidator do
  def email_errors(email)
    donation = build(:donation, email:)
    donation.valid?
    donation.errors[:email]
  end

  describe "behavior (via Donation#email)" do
    it "accepts an ordinary address, including whitespace the model normalizes away" do
      expect(email_errors("John.Smith+tag@sub.example.co.uk\n")).to be_empty
    end

    it "accepts a punycode TLD" do
      expect(email_errors("john@example.xn--p1ai")).to be_empty
    end

    {
      "quoted local part"         => '"john smith"@example.com',
      "commented local part"      => "john(note)@example.com",
      "IP address domain"         => "john@127.0.0.1",
      "single-label domain"       => "john@localhost",
      "internationalized domain"  => "john@exämple.com",
      "non-ASCII local part"      => "jöhn@example.com",
      "overlong local part"       => "#{"j" * 65}@example.com",
      "leading dot in local part" => ".john@example.com",
      "consecutive dots"          => "john..smith@example.com",
      "trailing dot in domain"    => "john@example.com.",
      "numeric TLD"               => "john@example.123"
    }.each do |description, email|
      it "rejects a #{description}" do
        expect(email_errors(email)).to include("does not appear to be a valid email address")
      end
    end
  end

  describe "is wired onto every email sent to Stripe as a customer" do
    [Donation, RecurringDonation].each do |model|
      it "guards #{model}#email" do
        expect(model.validators_on(:email).map(&:class)).to include(StripeEmailValidator)
      end
    end
  end
end
