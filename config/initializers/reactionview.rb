# frozen_string_literal: true

# ReActionView (https://reactionview.dev) compiles our HTML views with Herb
# instead of Rails' default ERB handler (Rails 8.2 does this by default). Herb
# parses the HTML and the Ruby together, so a view with mismatched tags or
# invalid nesting fails to compile instead of rendering broken markup.
#
# A view can also declare UI state the browser owns with `<%# herb:state %>`
# and change it from `data-herb-*` attributes, so a form that shows, hides or
# requires fields as you fill it in needs no JavaScript of its own. See
# dev-docs/guides/herb_views.md.
ReActionView.configure do |config|
  config.intercept_erb = true
  # Templates that ship inside gems (Blazer, Flipper UI, ...) aren't ours to fix.
  config.external_template_mode = :skip

  # Only views that say `<%# herb:slots client %>` are reactive. Turning
  # `slots` on would give every other view slot markers too.
  config.slots = false

  # Tests fail on invalid nesting, unsafe attribute output and the like, so CI
  # catches them. Elsewhere the page just renders.
  config.validation_mode = Rails.env.test? ? :raise : :none

  config.debug_mode = false
  config.instrumentation.enabled = false
end

# A reactive view ships a manifest of its states that the browser runtime
# reads. ReActionView collects these and has a middleware add them to the end of
# <body>, which a Turbo Stream or frame response doesn't have, so a reactive
# partial streamed onto a page that never rendered it before (the first expense
# on a report) wouldn't react. Herb can instead write each manifest inline, once
# per response, next to the view's first rendering; ReActionView just doesn't
# expose the option.
module InlineHerbManifests
  private

  def slot_visitors(template, source, mark: true)
    super.map { |visitor| visitor.tap { _1.instance_variable_set(:@deliver, :inline) } }
  end
end

ReActionView::Template::Handlers::Herb.prepend(InlineHerbManifests)
