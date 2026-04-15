# frozen_string_literal: true

require "delegate"

module ReactOnRailsMigrationHelper
  class ViewProxy < SimpleDelegator
    include ReactOnRails::Helper

  end

  def react_on_rails_component(component_name, props: {}, html_options: {}, prerender: false, **options)
    react_on_rails_options = options.merge(
      props: props,
      prerender: prerender,
      html_options: html_options,
    )

    ViewProxy.new(self).react_component(component_name, react_on_rails_options)
  end
end
