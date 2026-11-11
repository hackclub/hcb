# frozen_string_literal: true

# ReActionView (https://reactionview.dev) renders our `.html.herb` templates
# with Herb::Engine. Those templates declare the UI state the browser owns with
# `<%# herb:state (...) %>` and change it with `data-herb-*` action attributes,
# so a form that only shows, hides or requires fields as you fill it in needs no
# JavaScript of its own. See dev-docs/guides/herb_views.md.
#
# `.html.erb` templates are untouched: `intercept_erb` stays off, so only files
# named `.html.herb` compile through Herb.
ReActionView.configure do |config|
  config.intercept_erb = false

  # Reactive templates. Every herb view also says `<%# herb:slots client %>`, so
  # a state change is handled in the browser and never re-requests the page.
  config.slots = :client

  # Validators report a `<div>` inside a `<p>`, nested links, unsafe attribute
  # output and the like. Tests raise on them so CI catches them; production
  # neither runs them nor injects their report into the page.
  config.validation_mode = if Rails.env.test?
                             :raise
                           elsif Rails.env.production?
                             :none
                           else
                             :overlay
                           end

  # Our layouts are still `.html.erb`, which is where ReActionView would load its
  # dev tools, so neither the debug attributes nor the dev server would be seen.
  config.debug_mode = false
  config.dev_server = false
  config.instrumentation.enabled = false
end

# When a page renders any herb view, ReActionView also maps server-side state
# (`herb_state` read in a controller) to the slots it feeds. To build that map
# it compiles the page's entry template and every partial it rendered with
# Herb's strict parser, `.html.erb` ones included, and plenty of valid ERB fails
# that parse (an omitted `</tbody>`, say). The failure is a SyntaxError, which
# ReActionView's `rescue StandardError` misses, so the page 500s.
#
# Our herb views only use state the browser owns, which the client tracks from
# each template's own manifest, so the map is always empty. Skip building it.
# Remove this if a controller ever starts reading `herb_state`.
module SkipServerStateDependencies
  private

  def deliver_slot_dependencies(_body, _options) = nil
end

ReActionView::Slots::Rendering.prepend(SkipServerStateDependencies)
