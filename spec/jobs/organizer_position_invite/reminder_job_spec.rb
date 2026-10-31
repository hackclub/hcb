# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrganizerPositionInvite::ReminderJob, type: :job do
  it "is scheduled when an invite is sent" do
    expect { create(:organizer_position_invite) }
      .to have_enqueued_job(described_class).exactly(3).times
  end

  it "is not scheduled for an invite sent to oneself" do
    expect { create(:organizer_position_invite, :sent_to_self) }
      .not_to have_enqueued_job(described_class)
  end

  it "is not scheduled for a signee until their contract is signed" do
    expect { create(:organizer_position_invite, is_signee: true) }
      .not_to have_enqueued_job(described_class)
  end

  it "reminds an invitee who hasn't responded" do
    invite = create(:organizer_position_invite)

    expect { described_class.perform_now(invite) }
      .to have_enqueued_mail(OrganizerPositionInvitesMailer, :reminder)
  end

  it "stays quiet once the invite is accepted, rejected, or canceled" do
    accepted = create(:organizer_position_invite, :accepted)
    rejected = create(:organizer_position_invite)
    rejected.reject
    canceled = create(:organizer_position_invite)
    canceled.cancel

    [accepted, rejected, canceled].each do |invite|
      expect { described_class.perform_now(invite.reload) }
        .not_to have_enqueued_mail(OrganizerPositionInvitesMailer, :reminder)
    end
  end
end
