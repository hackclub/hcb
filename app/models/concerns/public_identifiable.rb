# frozen_string_literal: true

# (@msw) Stripe-like public IDs that don't require adding a column to the database.
module PublicIdentifiable
  extend ActiveSupport::Concern

  included do
    class_attribute :public_id_prefix
  end

  def public_id
    "#{self.public_id_prefix}_#{hashid}"
  end

  module ClassMethods
    def set_public_id_prefix(prefix)
      self.public_id_prefix = prefix.to_s.downcase
    end

    def find_by_public_id(id)
      hash = hashid_from_public_id(id)
      return nil if hash.nil?

      find_by_hashid(hash)
    end

    def find_by_public_id!(id)
      obj = find_by_public_id id
      raise ActiveRecord::RecordNotFound.new(nil, self.name) if obj.nil?

      obj
    end

    # Batch counterpart to `find_by_public_id`, for loading many records in one
    # query rather than one query per public id. Ids that aren't prefixed for
    # this model are dropped.
    #
    # Inherits `where_hashid`'s contract: unordered, de-duplicated, unknown ids
    # silently omitted, and the relation is not scoped to an owner. See it for
    # the batch size limit.
    def where_public_id(ids)
      ids = [ids] unless ids.is_a?(Array)

      where_hashid(ids.filter_map { |id| hashid_from_public_id(id) })
    end

    def get_public_id_prefix
      return self.public_id_prefix.to_s.downcase if self.public_id_prefix.present?

      raise NotImplementedError, "The #{self.class.name} model includes PublicIdentifiable module, but set_public_id_prefix hasn't been called."
    end

    private

    # ex. 'org_h1izp' => 'h1izp'. nil unless the id is prefixed for this model.
    def hashid_from_public_id(id)
      return nil unless id.is_a? String

      parts = id.split("_")
      return nil unless parts.first.to_s.downcase == self.get_public_id_prefix

      parts.last
    end
  end
end
