# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event::SubOrganizationTree, type: :model do
  let(:root) { create(:event) }
  let(:child) { create(:event, parent: root) }
  let(:grandchild) { create(:event, parent: child) }
  let(:great_grandchild) { create(:event, parent: grandchild) }
  let(:other_child) { create(:event, parent: root) }

  subject(:tree) { described_class.new(descendant_ids: [child, grandchild, great_grandchild, other_child].map(&:id)) }

  describe "#ancestor_ids" do
    it "walks up to, but not into, the organization the tree hangs from" do
      expect(tree.ancestor_ids(great_grandchild.id)).to eq([grandchild.id, child.id])
    end

    it "is empty for a direct sub-organization" do
      expect(tree.ancestor_ids(child.id)).to eq([])
    end
  end

  describe "#subtree_ids" do
    it "returns the roots together with everything beneath them" do
      expect(tree.subtree_ids([child.id])).to contain_exactly(child.id, grandchild.id, great_grandchild.id)
    end
  end

  describe "#descendant_ids_by_root" do
    it "groups everything beneath each root, the root itself excluded" do
      expect(tree.descendant_ids_by_root([child.id, grandchild.id])).to match(
        child.id      => contain_exactly(grandchild.id, great_grandchild.id),
        grandchild.id => [great_grandchild.id]
      )
    end

    it "leaves out a root with nothing beneath it" do
      expect(tree.descendant_ids_by_root([other_child.id])).to eq({})
    end

    it "does not reach through a soft-deleted event to what sits beneath it" do
      grandchild.update_columns(deleted_at: Time.current)

      expect(tree.descendant_ids_by_root([child.id])).to eq({})
    end
  end
end
