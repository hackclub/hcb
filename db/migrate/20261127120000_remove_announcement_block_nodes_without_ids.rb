# frozen_string_literal: true

# Some announcements were saved with block nodes whose `attrs.id` is nil (all
# DonationGoal blocks in prod). They render as the unknown block placeholder
# and would fail the new `content_has_block_ids` validation on their next save,
# so drop those nodes from the content.
class RemoveAnnouncementBlockNodesWithoutIds < ActiveRecord::Migration[8.1]
  def up
    Announcement.with_deleted.where("content::text LIKE ?", "%Announcement::Block::%").find_each do |announcement|
      content = announcement.content
      next unless content.is_a?(Hash) && content["content"].is_a?(Array)

      cleaned = strip_blocks_without_ids(content["content"])
      next if cleaned == content["content"]

      announcement.update_column(:content, content.merge("content" => cleaned))
    end
  end

  def down
    # Irreversible: the removed nodes pointed at no block.
  end

  private

  def strip_blocks_without_ids(nodes)
    nodes.filter_map do |node|
      next node unless node.is_a?(Hash)

      attrs = node["attrs"]
      next if node["type"].to_s.start_with?("Announcement::Block::") && !(attrs.is_a?(Hash) && attrs["id"].present?)

      node["content"].is_a?(Array) ? node.merge("content" => strip_blocks_without_ids(node["content"])) : node
    end
  end

end
