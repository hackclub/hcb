# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardLocking::CardholderBehavior do
  let(:user) { create(:user) }

  describe "engineering alert on cards_locked transitions" do
    it "alerts engineering when cards become locked" do
      expect { user.update!(cards_locked: true) }
        .to have_enqueued_mail(EngineeringAlertMailer, :cards_locked).once
    end

    it "alerts engineering when cards become unlocked" do
      user.update!(cards_locked: true)

      expect { user.update!(cards_locked: false) }
        .to have_enqueued_mail(EngineeringAlertMailer, :cards_unlocked).once
    end

    it "does not alert on a save that leaves cards_locked unchanged" do
      expect { user.update!(card_locking_suppressed_until: 1.hour.from_now) }
        .not_to have_enqueued_mail(EngineeringAlertMailer)
    end
  end
end
