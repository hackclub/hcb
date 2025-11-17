# frozen_string_literal: true

require "rails_helper"

RSpec.describe("Flipper configuration") do
  describe "actor_names_source" do
    it "returns actor names for events" do
      event = create(:event, name: "Hack the Planet")

      actor_names = Flipper::UI.configuration.actor_names_source.call([event.flipper_id])

      expect(actor_names).to eq({ event.flipper_id => "Hack the Planet" })
    end

    it "returns actor names for users" do
      user = create(:user, full_name: "Orpheus the Dinosaur", email: "orpheus@hackclub.com")

      actor_names = Flipper::UI.configuration.actor_names_source.call([user.flipper_id])

      expect(actor_names).to eq({ user.flipper_id => "Orpheus the Dinosaur &lt;orpheus@hackclub.com&gt;" })
    end

    it "handles users without names" do
      user = create(:user, full_name: nil, email: "orpheus@hackclub.com")

      actor_names = Flipper::UI.configuration.actor_names_source.call([user.flipper_id])

      expect(actor_names).to eq({ user.flipper_id => "orpheus@hackclub.com" })
    end

    it "ignores unknown or no longer existent keys" do
      event = create(:event, name: "Hack the Planet")
      user = create(:user, full_name: nil, email: "orpheus@hackclub.com")

      deleted_event = create(:event)
      deleted_event_flipper_id = deleted_event.flipper_id
      deleted_event.destroy!

      deleted_user = create(:user)
      deleted_user_flipper_id = deleted_user.flipper_id
      deleted_user.destroy!

      actor_names = Flipper::UI.configuration.actor_names_source.call(
        [
          user.flipper_id,
          "User;✌️",
          deleted_user_flipper_id,
          event.flipper_id,
          "Event; yay!",
          deleted_event_flipper_id,
        ]
      )

      expect(actor_names).to eq(
        {
          user.flipper_id  => "orpheus@hackclub.com",
          event.flipper_id => "Hack the Planet",
        }
      )
    end
  end
end
