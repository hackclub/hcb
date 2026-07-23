# frozen_string_literal: true

require "delegate"

module ReactOnRailsMigrationHelper
  REACT_ON_RAILS_OPTION_KEYS = %i[
    auto_load_bundle hydrate_on id logging_on_server raise_on_prerender_error
    random_dom_id render_mode replay_console store_dependencies throw_js_errors trace
  ].freeze

  class ViewProxy < SimpleDelegator
    include ReactOnRails::Helper

  end

  def react_on_rails_component(component_name, props = nil, html_options = nil, **options)
    explicit_props = options.delete(:props) if options.key?(:props)
    explicit_html_options = options.delete(:html_options) || {}
    prerender = options.key?(:prerender) ? options.delete(:prerender) : false
    react_on_rails_options = options.extract!(*REACT_ON_RAILS_OPTION_KEYS)
    implicit_props = options

    react_on_rails_options = react_on_rails_options.merge(
      props: resolve_component_props(explicit_props, props, implicit_props),
      prerender: prerender,
      html_options: normalize_html_options(html_options).merge(normalize_html_options(explicit_html_options)),
    )

    ViewProxy.new(self).react_component(component_name, react_on_rails_options)
  end

  private

  def resolve_component_props(explicit_props, positional_props, implicit_props)
    base_props = if explicit_props.nil?
                   positional_props || {}
                 else
                   explicit_props
                 end

    return base_props if implicit_props.empty?
    return implicit_props if base_props.blank?
    return base_props.merge(implicit_props) if base_props.is_a?(Hash)

    raise ArgumentError, "implicit keyword props require hash props"
  end

  def normalize_html_options(html_options)
    return {} if html_options.nil?
    return { tag: html_options } if html_options.is_a?(Symbol)

    html_options.to_h
  end
end
