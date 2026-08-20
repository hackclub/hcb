# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoice, type: :model do
  before do
    expect_any_instance_of(Sponsor).to receive(:create_stripe_customer).and_return(true)
  end

  it "is valid" do
    invoice = create(:invoice)
    expect(invoice).to be_valid
  end

  # Part of adding shared_commentable support for Invoice-linked HcbCodes/Ledger::Items.
  describe "as a Commentable" do
    it "accepts a comment" do
      invoice = create(:invoice)
      comment = create(:comment, commentable: invoice)

      expect(comment).to be_valid
    end

    describe "#comment_recipients_for" do
      it "includes the creator and event members, but not the commenter" do
        invoice = create(:invoice)
        organizer = create(:user)
        create(:organizer_position, event: invoice.event, user: organizer, role: :member)
        commenter = create(:user)
        comment = create(:comment, commentable: invoice, user: commenter, content: "hi")

        recipients = invoice.comment_recipients_for(comment)

        expect(recipients).to include(invoice.creator.email_address_with_name)
        expect(recipients).to include(organizer.email_address_with_name)
        expect(recipients).not_to include(commenter.email_address_with_name)
      end
    end

    describe "#comment_mentionable" do
      it "includes event members as mentionable users" do
        invoice = create(:invoice)
        organizer = create(:user)
        create(:organizer_position, event: invoice.event, user: organizer, role: :member)

        expect(invoice.comment_mentionable).to include(organizer)
      end
    end

    describe "#comment_mailer_subject" do
      it "includes the item description" do
        invoice = create(:invoice, item_description: "Stickers")

        expect(invoice.comment_mailer_subject).to include("Stickers")
      end
    end
  end
end
