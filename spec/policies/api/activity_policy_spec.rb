# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::ActivityPolicy do
  subject(:policy) { described_class.new(nil, activity) }

  let(:indexable_event) { create(:event, is_public: true, is_indexable: true, demo_mode: false) }
  let(:non_indexable_event) { create(:event, is_public: true, is_indexable: false, demo_mode: false) }
  let(:non_public_event) { create(:event, is_public: false, is_indexable: true, demo_mode: false) }
  let(:demo_event) { create(:event, is_public: true, is_indexable: true, demo_mode: true) }

  # `PublicActivity.enabled = false` in rails_helper.rb disables the
  # gem's automatic activity creation, so we build rows directly to
  # exercise the policy's resolution logic without firing tracked
  # callbacks.
  def build_activity(attrs)
    trackable = attrs[:trackable] || indexable_event
    PublicActivity::Activity.create!({ key: "test.activity", trackable: }.merge(attrs))
  end

  describe "#show?" do
    context "when the activity's event_id points to an indexable event" do
      let(:activity) { build_activity(event_id: indexable_event.id) }

      it "allows" do
        expect(policy.show?).to be true
      end
    end

    context "when event_id points to a non-indexable event" do
      let(:activity) { build_activity(event_id: non_indexable_event.id) }

      it "denies" do
        expect(policy.show?).to be false
      end
    end

    context "when event_id points to a non-public (private) event" do
      let(:activity) { build_activity(event_id: non_public_event.id) }

      it "denies" do
        expect(policy.show?).to be false
      end
    end

    context "when event_id points to a demo-mode event" do
      let(:activity) { build_activity(event_id: demo_event.id) }

      it "denies" do
        expect(policy.show?).to be false
      end
    end

    context "when recipient_type='Event' and recipient_id is indexable" do
      let(:activity) do
        build_activity(recipient_type: "Event", recipient_id: indexable_event.id)
      end

      it "allows" do
        expect(policy.show?).to be true
      end
    end

    context "when recipient_type='Event' and recipient_id is non-indexable" do
      let(:activity) do
        build_activity(recipient_type: "Event", recipient_id: non_indexable_event.id)
      end

      it "denies" do
        expect(policy.show?).to be false
      end
    end

    # Disbursements set `event_id` to the source org and `recipient` to
    # the destination. The Activity entity serializes the recipient, so
    # authorizing on `event_id` (the source) would leak the destination's
    # org data. The policy must deny here.
    context "when event_id is indexable but recipient_type='Event' with non-indexable recipient_id" do
      let(:activity) do
        build_activity(
          event_id: indexable_event.id,
          recipient_type: "Event",
          recipient_id: non_indexable_event.id
        )
      end

      it "denies (recipient takes precedence in serialization)" do
        expect(policy.show?).to be false
      end
    end

    # Symmetric inverse: private source, public destination. Serializer
    # renders the public destination, which is the right behavior.
    context "when event_id is non-indexable but recipient_type='Event' with indexable recipient_id" do
      let(:activity) do
        build_activity(
          event_id: non_indexable_event.id,
          recipient_type: "Event",
          recipient_id: indexable_event.id
        )
      end

      it "allows" do
        expect(policy.show?).to be true
      end
    end

    context "when recipient_type='User' and event_id is indexable" do
      let(:user) { create(:user) }
      let(:activity) do
        build_activity(
          recipient_type: "User",
          recipient_id: user.id,
          event_id: indexable_event.id
        )
      end

      it "allows (falls back to event_id)" do
        expect(policy.show?).to be true
      end
    end

    context "when the activity has no event association at all" do
      let(:user) { create(:user) }
      let(:activity) do
        build_activity(recipient_type: "User", recipient_id: user.id)
      end

      it "denies" do
        expect(policy.show?).to be false
      end
    end

    context "when the serialized event has been soft-deleted" do
      let(:activity) { build_activity(event_id: indexable_event.id) }

      before { indexable_event.destroy }

      it "denies" do
        expect(policy.show?).to be false
      end
    end
  end
end
