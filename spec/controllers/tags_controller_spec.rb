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

      post(:create, params: { event_id: event.slug, label: "Snacks", color: "muted", emoji: "🍕", ledger_item_id: hcb_code.reload.ledger_item.hashid })

      tag = event.tags.sole
      expect(tag.label).to eq("Snacks")
      expect(hcb_code.reload.tags).to include(tag)
    end

    it "refuses to attach the tag to a transaction from another organization" do
      other_event = create(:event)
      create(:organizer_position, user:, event: other_event)
      hcb_code = hcb_code_belonging_to(other_event)

      post(:create, params: { event_id: event.slug, label: "Snacks", color: "muted", emoji: "🍕", ledger_item_id: hcb_code.reload.ledger_item.hashid })

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
        post(:create, params: { event_id: event.slug, label: "Snacks", color: "muted", emoji: "🍕", ledger_item_id: hcb_code.reload.ledger_item.hashid })
      }.not_to raise_error

      expect(event.tags.sole).to eq(concurrent_tag)
      expect(hcb_code.reload.tags).to include(concurrent_tag)
    end
  end
end

RSpec.describe TagsController, "#set_index" do
  include SessionSupport

  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let!(:tags) { %w[Food Travel Supplies].map { |label| create(:tag, event:, label:) } }

  def set_index(tag, index, event: self.event)
    post(:set_index, params: { event_id: event.slug, id: tag.id, index: }, as: :json)
  end

  context "as a member" do
    before do
      create(:organizer_position, user:, event:, role: :member)
      create_session(user, verified: true)
    end

    it "moves the tag and renumbers the event's tags" do
      set_index(tags[2], 0)

      expect(response).to have_http_status(:no_content)
      expect(event.tags.reload.map(&:label)).to eq(%w[Supplies Food Travel])
      expect(event.tags.map(&:sort_index)).to eq([0, 1, 2])
    end

    it "sorts a tag created after a reorder last" do
      set_index(tags[1], 2)
      newer = create(:tag, event:, label: "Newer")

      expect(newer.sort_index).to be_nil
      expect(event.tags.reload.map(&:label)).to eq(%w[Food Supplies Travel Newer])
    end

    it "rejects an index outside the event's tags" do
      set_index(tags[0], 3)
      expect(response).to have_http_status(:bad_request)

      set_index(tags[0], -1)
      expect(response).to have_http_status(:bad_request)

      expect(event.tags.reload.map(&:label)).to eq(%w[Food Travel Supplies])
    end

    it "does not find another organization's tag" do
      other_event = create(:event)
      other_tag = create(:tag, event: other_event, label: "Elsewhere")

      expect { set_index(other_tag, 0) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context "as a reader" do
    before do
      create(:organizer_position, user:, event:, role: :reader)
      create_session(user, verified: true)
    end

    it "is not allowed" do
      set_index(tags[2], 0)

      expect(response).to have_http_status(:redirect)
      expect(flash[:error]).to include("not authorized")
      expect(event.tags.reload.map(&:label)).to eq(%w[Food Travel Supplies])
    end
  end
end
