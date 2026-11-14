# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagsController do
  include SessionSupport

  describe "#create" do
    let(:user) { create(:user) }
    let(:event) { create(:event) }

    before do
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)
    end

    def hcb_code_belonging_to(event)
      canonical_transaction = create(:canonical_transaction)
      create(:canonical_event_mapping, canonical_transaction:, event:)
      canonical_transaction.local_hcb_code
    end

    it "creates the tag and attaches it to a transaction in the same organization" do
      hcb_code = hcb_code_belonging_to(event)

      post(:create, params: { event_id: event.slug, label: "Snacks", color: "muted", emoji: "🍕", hcb_code_id: hcb_code.hashid })

      tag = event.tags.sole
      expect(tag.label).to eq("Snacks")
      expect(hcb_code.reload.tags).to include(tag)
    end

    it "refuses to attach the tag to a transaction from another organization" do
      other_event = create(:event)
      create(:organizer_position, user:, event: other_event)
      hcb_code = hcb_code_belonging_to(other_event)

      post(:create, params: { event_id: event.slug, label: "Snacks", color: "muted", emoji: "🍕", hcb_code_id: hcb_code.hashid })

      expect(hcb_code.reload.tags).to be_empty
    end

    it "recovers when the same tag is created concurrently (e.g. a double submit)" do
      hcb_code = hcb_code_belonging_to(event)
      concurrent_tag = nil
      handled = false

      # Simulate another request winning the race and creating the same tag
      # in between this request's initial lookup (which finds nothing) and
      # its own attempted create (whose uniqueness validation then fails).
      allow_any_instance_of(Tag).to receive(:save).and_wrap_original do |original_save, *args, &block|
        tag = original_save.receiver

        if !handled && tag.new_record? && tag.label == "Snacks"
          handled = true
          concurrent_tag = Tag.create!(label: "Snacks", event:, color: "blue", emoji: "🎉")
          tag.errors.add(:label, :taken)
          false
        else
          original_save.call(*args, &block)
        end
      end

      expect {
        post(:create, params: { event_id: event.slug, label: "Snacks", color: "muted", emoji: "🍕", hcb_code_id: hcb_code.hashid })
      }.not_to raise_error

      expect(event.tags.sole).to eq(concurrent_tag)
      expect(hcb_code.reload.tags).to include(concurrent_tag)
    end
  end
end
