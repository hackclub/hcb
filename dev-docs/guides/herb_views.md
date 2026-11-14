# Herb views

Every HTML view is compiled by [Herb](https://herb-tools.dev) through [ReActionView](https://reactionview.dev) instead of Rails' default ERB handler (`config/initializers/reactionview.rb`). Herb reads the HTML and the Ruby together, so a view with a mismatched tag, an `<% if %>` that opens a tag in one branch and closes it in another, or a `<div>` inside a `<p>` fails to compile. In tests it also fails on unsafe output such as `<%= "disabled" if x %>` in attribute position. Write `<% if x %>disabled<% end %>` instead.

A view can also be **reactive**: it declares UI state the browser owns, reads it like a Ruby local and changes it from an HTML attribute. The server renders each state's starting value and the browser updates every read in place, with no request and no JavaScript of our own. This is what replaced Alpine.js.

> [!WARNING]
> Reactive views are experimental in ReActionView 0.6. Keep the `reactionview` gem and npm package on the same version.

## A reactive view

```erb
<%# locals: (form:) %>
<%# herb:slots client %>
<%# herb:state (selected_role: "member") %>

<%= form.select :role, OrganizerPositionInvite.roles.keys, { selected: "member" }, data: { herb_set: "selected_role=$value" } %>

<div hidden="<%= selected_role != "manager" %>">
  Only managers see this.
</div>
```

- `<%# herb:slots client %>` makes the view reactive. Views without it render normally.
- `<%# herb:state (...) %>` declares the states on one line. A default is a String, Integer or Boolean literal, or a strict local (see below).
- `data-herb-set="name=$value"` writes a field's value as it changes (`$value` of a checkbox is whether it's checked). `data-herb-toggle="open"` flips a Boolean, `data-herb-set="editing=true"` sets a literal on click. These work through helpers' `data:` options.
- `hidden="<%= condition %>"` (or `disabled`, `required`, `checked`) on a tag written in the template is added or removed as the state changes. This only works in reactive views; elsewhere `hidden="<%= false %>"` prints `"false"`.

The [state](https://herb-tools.dev/language/state) and [actions](https://herb-tools.dev/language/actions) docs cover the rest.

## Rules of thumb

- **Show and hide with `hidden`, not `<% if %>`.** The browser can evaluate `==`, `!=`, `!`, `&&`, `||`, Integer `>`/`<` and predicates like `blank?`, but it can't run the Ruby inside an `<% if %>` branch, like a form field.
- **Swap groups of fields with a `<fieldset class="contents">` that is both `hidden` and `disabled`** under the same condition. Hidden fields are still submitted and still `required`; disabled ones are neither.
- **Never read a state inside a helper call** (`selected: selected_role`). Only the server could recompute it.
- **Name a state that mirrors a field `selected_<field>`.** The `herb-state-valid-reads` lint rule matches state names anywhere in an output tag, so a state called `role` trips on `form.label :role`.
- **In a reactive view, pass `tag.*`, `content_tag` and `link_to` only literal hashes.** Herb compiles those helpers itself there and mishandles anything else: `data: some_hash` becomes one `data="{...}"` attribute, `**options` is dropped and a `nil` value prints `"null"`. Form builder methods and non-reactive views aren't affected, so move dynamic markup into a plain partial.
- **Give a state a literal default when an action sets it to a literal.** `data-herb-set="flag=false"` on a Boolean seeded from a strict local writes the String `"false"`, which is truthy.

## Starting from a record, and sharing with a partial

A state's default can be one of the view's strict locals, so state that starts from a record lives in a partial:

```erb
<%# locals: (affiliation:, form:, initial_type: affiliation.name.to_s) %>
<%# herb:slots client %>
<%# herb:state (selected_type: initial_type) %>
```

A partial's states are its own unless the caller binds one to its own: `render "organizer_position_invites/role_and_control_form", form:, state: { selected_role: selected_role }`. Use the partial's full path.

## When JavaScript is still needed

Anything beyond writing a value (fetching, counting words, focus, browser APIs) stays in a Stimulus controller, which can read and write the states around it:

```js
import { Controller } from '@hotwired/stimulus'
import { useState } from 'reactionview'

export default class extends Controller {
  connect() {
    useState(this) // this.state.get/set/on, plus <name>Changed(value) callbacks
  }
}
```

When which values show something comes from a model (wire fields per country, Wise fields per currency), the `state-switch` controller shows and enables targets whose `data-state-switch-when` (or `-unless`) lists the state's value.
