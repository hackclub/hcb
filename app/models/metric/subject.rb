# frozen_string_literal: true

class Metric
  module Subject
    extend ActiveSupport::Concern

    included do
      def self.subject_model
        self.name.deconstantize.split("::").last.constantize
      end

      def self.subject_name
        self.subject_model.name.underscore
      end

      alias_method subject_name, :subject
      alias_attribute "#{subject_name}_id", :subject_id
    end
  end

end
