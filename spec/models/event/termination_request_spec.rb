# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event::TerminationRequest do
  include ActiveJob::TestHelper

  let(:event) { create(:event) }
  let(:signee) { create(:user) }

  it "requires a reason" do
    request = build(:event_termination_request, event:, requested_by: signee, reason: "")

    expect(request).not_to be_valid
    expect(request.errors[:reason]).to be_present
  end

  it "allows only one pending request per organization" do
    create(:event_termination_request, event:, requested_by: signee)
    duplicate = build(:event_termination_request, event:, requested_by: signee)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:base]).to include("This organization already has a pending termination request.")
  end

  it "allows a new request once the previous one is withdrawn or closed" do
    create(:event_termination_request, event:, requested_by: signee).withdraw!
    create(:event_termination_request, event:, requested_by: signee).close!(create(:user, :make_admin))

    expect(build(:event_termination_request, event:, requested_by: signee)).to be_valid
  end

  it "emails operations and the requester once created" do
    request = nil
    perform_enqueued_jobs do
      request = create(:event_termination_request, event:, requested_by: signee)
    end

    recipients = ActionMailer::Base.deliveries.last(2).flat_map(&:to)
    expect(recipients).to contain_exactly(ApplicationMailer::OPERATIONS_EMAIL, signee.email)
    expect(request).to be_pending
  end

  describe "#withdraw!" do
    it "marks a pending request as withdrawn" do
      request = create(:event_termination_request, event:, requested_by: signee)

      request.withdraw!

      expect(request.status).to eq(:withdrawn)
      expect(event.reload.pending_termination_request).to be_nil
    end

    it "refuses to withdraw a closed request" do
      request = create(:event_termination_request, event:, requested_by: signee)
      request.close!(create(:user, :make_admin))

      expect { request.withdraw! }.to raise_error(ArgumentError)
    end
  end

  describe "#close! and #reopen!" do
    it "records who closed the request and can reopen it" do
      admin = create(:user, :make_admin)
      request = create(:event_termination_request, event:, requested_by: signee)

      request.close!(admin)
      expect(request.status).to eq(:closed)
      expect(request.closed_by).to eq(admin)

      request.reopen!
      expect(request.status).to eq(:pending)
      expect(request.closed_by).to be_nil
    end

    it "refuses to reopen a withdrawn request" do
      request = create(:event_termination_request, event:, requested_by: signee)
      request.withdraw!

      expect { request.reopen! }.to raise_error(ArgumentError)
    end
  end
end
