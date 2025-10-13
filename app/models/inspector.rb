# frozen_string_literal: true

module Inspector
  def self.resource_types
    Zeitwerk::Loader.eager_load_all

    descendants = ObjectSpace.each_object(Class).select { |c| c < ApplicationRecord }

    descendants.filter_map(&:name)
  end

  def self.find_relations(object)
    if object.class < ApplicationRecord
      object = object.attributes
    end

    resource_type_keys = resource_types.index_by { |type| "#{type.underscore}_id" }

    association_keys = object.keys.select do |key|
      key.ends_with?("_id") && object[key].present? && resource_type_keys[key].present?
    end

    association_keys.map do |key|
      [resource_type_keys[key], object[key]]
    end.to_h
  end

  def self.find_object(resource, id)
    return nil unless resource.in?(resource_types)
    klass = resource.constantize

    object = klass.find_by(id: id)
    object ||= klass.try(:find_by_public_id, id)
    object ||= klass.try(:find_by_hashid, id)
    object ||= klass.find_by(hcb_code: id) if "hcb_code".in? klass.columns.collect(&:name)
    object ||= klass.try(:friendly)&.find(id, allow_nil: true)
    object ||= klass.try(:find_by_public_id, id)
    object ||= klass.try(:search_name, id)
    object ||= klass.try(:search_memo, id)
    object ||= klass.try(:search_recipient, id)
    object ||= klass.try(:search_description, id)

    object = object.first if object.class < Enumerable

    object
  end

  def self.object_for(path)
    route = Rails.application.routes.recognize_path(path)
    model_name = route[:controller].singularize.classify

    if model_name.in?(resource_types)
      find_object(model_name, route["#{model_name.underscore}_id".to_sym] || route[:id])
    end
  end
end
