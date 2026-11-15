# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommentMailer do
  describe "#notification" do
    it "does not send (or raise) when the comment was deleted before the mail is sent" do
      event = create(:event, name: "Daydream")
      owner = create(:user, full_name: "Report Owner", email: "owner@example.com")
      commenter = create(:user, full_name: "Commenter Person", email: "commenter@example.com")

      report = Reimbursement::Report.create!(name: "Travel", user: owner, event:, currency: "USD")
      comment = Comment.create!(commentable: report, user: commenter, content: "hi")

      # Simulate the comment (and therefore every comment on the report) being
      # deleted in the window between the comment being created and the
      # already-enqueued notification mailer job actually running.
      comment.destroy!

      mail = described_class.with(comment:).notification

      expect { mail.deliver_now }.not_to(change { ActionMailer::Base.deliveries.count })
    end
  end
end
