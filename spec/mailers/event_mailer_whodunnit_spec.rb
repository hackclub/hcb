# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventMailer, type: :mailer do
  describe "#transparency_mode_enabled" do
    let(:parent_event) { create(:event) }
    let(:event) { create(:event, parent: parent_event) }

    before do
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
      create(:organizer_position, event:, role: :manager)
    end

    def body_for(whodunnit)
      EventMailer.with(event:, whodunnit:).transparency_mode_enabled.body.encoded
    end

    it "describes an organizer of a parent organization as a manager" do
      user = create(:user)
      create(:organizer_position, user:, event: parent_event, role: :manager)

      expect(body_for(user)).to include("organization manager")
    end

    it "describes an organizer of an unrelated organization as an HCB admin" do
      user = create(:user, :make_admin)
      create(:organizer_position, user:, event: create(:event), role: :manager)

      expect(body_for(user)).to include("HCB admin")
    end

    it "describes a removed organizer as an HCB admin" do
      user = create(:user, :make_admin)
      create(:organizer_position, user:, event:, role: :manager).destroy!

      expect(body_for(user)).to include("HCB admin")
    end
  end
end
