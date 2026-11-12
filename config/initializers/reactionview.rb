# frozen_string_literal: true

require "herb/engine/runtime/middleware"

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

# Reactive views record the state the browser runtime needs while they render;
# this middleware adds it to the page. ReActionView only installs it alongside
# `slots`, the debug tools or validation overlays, none of which we use.
Rails.application.config.middleware.use Herb::Engine::Runtime::Middleware
