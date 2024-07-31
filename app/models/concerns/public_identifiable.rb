# frozen_string_literal: true

# (@msw) Stripe-like public IDs that don't require adding a column to the
# database. They're given out to partners (givebutter at time of writing), and
# will impact partners if changed.
module PublicIdentifiable
  extend ActiveSupport::Concern

  included do
    include Hashid::Rails
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
      return nil unless id.is_a? String

      prefix = id.split("_").first.to_s.downcase
      hash = id.split("_").last
      return nil unless prefix == self.get_public_id_prefix

      # ex. 'org_h1izp'
      find_by_hashid(hash)
    end

    def find_by_public_id!(id)
      obj = find_by_public_id id
      raise ActiveRecord::RecordNotFound.new(nil, self.name) if obj.nil?

      obj
    end

    def get_public_id_prefix
      return self.public_id_prefix.to_s.downcase if self.public_id_prefix.present?

      raise NotImplementedError, "The #{self.class.name} model includes PublicIdentifiable module, but set_public_id_prefix hasn't been called."
    end
  end
end
