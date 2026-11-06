# frozen_string_literal: true

require "rails_helper"

RSpec.describe HcbCode, "#comment_recipients_for" do
  let(:event) { create(:event) }
  let(:hcb_code) { create(:canonical_pending_transaction, event:, amount_cents: -1000).local_hcb_code }
  let(:organizer) { create(:user) }
  let(:auditor) { create(:user, :make_auditor) }

  before do
    create(:organizer_position, user: organizer, event:)
  end

  it "notifies mentioned users but not the commenter" do
    mentioned = create(:user)
    comment = create(:comment, commentable: hcb_code, user: organizer, content: "hey @#{mentioned.email}")

    recipients = hcb_code.comment_recipients_for(comment)

    expect(recipients).to include(mentioned.email_address_with_name)
    expect(recipients).not_to include(organizer.email_address_with_name)
  end

  context "with an admin-only comment" do
    it "only notifies auditors, even when a non-auditor is mentioned" do
      point_of_contact = create(:user, :make_admin)
      event.update!(point_of_contact:)
      mentioned = create(:user)
      comment = create(:comment, commentable: hcb_code, user: auditor, admin_only: true, content: "@#{mentioned.email}")
      other_auditor = create(:user, :make_auditor)
      create(:comment, commentable: hcb_code, user: other_auditor, admin_only: true)

      recipients = hcb_code.comment_recipients_for(comment)

      expect(recipients).to contain_exactly(other_auditor.email_address_with_name, point_of_contact.email_address_with_name)
    end

    it "does not raise when an event has no point of contact" do
      event.update!(point_of_contact: nil)
      comment = create(:comment, commentable: hcb_code, user: auditor, admin_only: true)

      expect { hcb_code.comment_recipients_for(comment) }.not_to raise_error
    end
  end
end
