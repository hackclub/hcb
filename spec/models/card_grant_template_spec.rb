# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrantTemplate, type: :model do
  it "is valid" do
    expect(build(:card_grant_template)).to be_valid
  end

  it "requires a name that is unique within the event" do
    template = create(:card_grant_template, name: "Pizza")

    expect(build(:card_grant_template, name: " ")).not_to be_valid
    expect(build(:card_grant_template, event: template.event, name: "Pizza ")).not_to be_valid
    expect(build(:card_grant_template, event: template.event, name: "pIZZA")).not_to be_valid
    expect(build(:card_grant_template, name: "Pizza")).to be_valid
  end

  it "enforces case-insensitive name uniqueness in the database" do
    template = create(:card_grant_template, name: "Pizza")
    duplicate = build(:card_grant_template, event: template.event, name: "PIZZA")

    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "rejects amounts too big for the database without raising" do
    template = build(:card_grant_template, amount_cents: 10**12)

    expect(template).not_to be_valid
    expect(template.errors[:amount_cents]).to include("is too big")
  end

  it "requires the keyword lock to be a valid regular expression" do
    template = build(:card_grant_template, keyword_lock: "[unclosed")

    expect(template).not_to be_valid
    expect(template.errors[:keyword_lock]).to include("is not a valid regular expression")
    expect(build(:card_grant_template, keyword_lock: "\\AApple")).to be_valid
  end

  it "validates purpose length, amount, and expiration days" do
    expect(build(:card_grant_template, purpose: "a" * (CardGrant::MAXIMUM_PURPOSE_LENGTH + 1))).not_to be_valid
    expect(build(:card_grant_template, amount_cents: 0)).not_to be_valid
    expect(build(:card_grant_template, amount_cents: nil)).to be_valid
    expect(build(:card_grant_template, expiration_days: 0)).not_to be_valid
  end

  it "does not have an email column" do
    expect(CardGrantTemplate.column_names).not_to include("email")
  end

  describe "#apply_to" do
    it "copies its settings onto a card grant" do
      template = create(
        :card_grant_template,
        amount_cents: 50_00,
        purpose: "Soldering iron",
        instructions: "Only buy a soldering iron",
        invite_message: "Happy hacking!",
        one_time_use: true,
        pre_authorization_required: true,
        merchant_lock: ["123", "456"],
        category_lock: ["hardware_stores"],
        keyword_lock: "\\AAmazon",
        banned_merchants: ["789"],
        banned_categories: ["betting_casino_gambling"],
        expiration_days: 30
      )
      card_grant = template.event.card_grants.build(email: "orpheus@hackclub.com")

      freeze_time do
        template.apply_to(card_grant)

        expect(card_grant.email).to eq("orpheus@hackclub.com")
        expect(card_grant.amount_cents).to eq(50_00)
        expect(card_grant.purpose).to eq("Soldering iron")
        expect(card_grant.instructions).to eq("Only buy a soldering iron")
        expect(card_grant.invite_message).to eq("Happy hacking!")
        expect(card_grant.one_time_use).to eq(true)
        expect(card_grant.pre_authorization_required).to eq(true)
        expect(card_grant.merchant_lock).to eq(["123", "456"])
        expect(card_grant.category_lock).to eq(["hardware_stores"])
        expect(card_grant.read_attribute(:keyword_lock)).to eq("\\AAmazon")
        expect(card_grant.banned_merchants).to eq(["789"])
        expect(card_grant.banned_categories).to eq(["betting_casino_gambling"])
        expect(card_grant.expiration_at).to eq(30.days.from_now.to_date)
      end
    end

    it "leaves the expiration date alone when the template doesn't set one" do
      template = create(:card_grant_template, expiration_days: nil)
      card_grant = template.event.card_grants.build

      template.apply_to(card_grant)

      expect(card_grant.expiration_at).to be_nil
    end
  end

  describe "#assign_from" do
    it "copies a card grant's settings but not its recipient" do
      event = create(:event)
      create(:card_grant_setting, event:)
      freeze_time do
        card_grant = event.card_grants.build(email: "orpheus@hackclub.com", amount_cents: 10_00, purpose: "Pizza", merchant_lock: ["123"], expiration_at: 10.days.from_now.to_date)

        template = event.card_grant_templates.build(name: "Pizza").assign_from(card_grant)

        expect(template.amount_cents).to eq(10_00)
        expect(template.purpose).to eq("Pizza")
        expect(template.merchant_lock).to eq(["123"])
        expect(template.expiration_days).to eq(10)
        expect(template).not_to respond_to(:email)
      end
    end

    it "doesn't store an expiration when the grant uses the event's default" do
      event = create(:event)
      create(:card_grant_setting, event:)
      card_grant = event.card_grants.build(amount_cents: 10_00)
      card_grant.expiration_at = card_grant.default_expiration_at.to_date

      template = event.card_grant_templates.build(name: "Default").assign_from(card_grant)

      expect(template.expiration_days).to be_nil
    end
  end
end
