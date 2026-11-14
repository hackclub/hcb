# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # Fields a policy has guarded with `fields`. See FieldGuard.
  class_attribute :guarded_fields, instance_accessor: false, default: Set.new.freeze

  def self.guarded_field?(field)
    guarded_fields.include?(field.to_sym)
  end

  # Whether the viewer of the response being rendered may read `field`. Always
  # true outside rendering. See FieldGuard.
  def readable?(field)
    FieldGuard.readable?(self, field.to_sym)
  end

end
