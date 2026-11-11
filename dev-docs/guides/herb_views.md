# Herb views

Views that respond as you fill them in (a field that appears when you pick an option, a section that shows for managers only, a word count) are written as reactive [ReActionView](https://reactionview.dev) templates. They're named `.html.herb` and compiled by Herb (`config/initializers/reactionview.rb`). Every other view is still a plain `.html.erb` rendered by Rails.

A herb view declares the UI state the browser owns, reads it like a Ruby local, and changes it from an HTML attribute. The server renders each state with its starting value and the client updates every read in place. There is no request and no JavaScript of our own. This replaced Alpine.js, whose expressions needed `'unsafe-eval'` in our Content Security Policy.

> [!WARNING]
> Reactive templates are experimental in ReActionView 0.6. Keep the `reactionview` gem and npm package on the same version, and re-check this guide when you upgrade them.

## A minimal example

```erb
<%# locals: (form:) %>
<%# herb:slots client %>
<%# herb:state (selected_role: "member") %>

<%= form.select :role, OrganizerPositionInvite.roles.keys, { selected: "member" }, data: { herb_set: "selected_role=$value" } %>

<div hidden="<%= selected_role != "manager" %>">
  Only managers see this.
</div>
```

- `<%# herb:slots client %>` goes in every herb view. It makes the browser build any part of the page a state change needs, so no change ever goes back to the server.
- `<%# herb:state (name: default, ...) %>` declares the states, all on one line. A default is a String, Integer or Boolean literal, or the name of a strict local to start from (see [Starting from a record](#starting-from-a-record)).
- `data-herb-set="name=$value"` writes the element's value when it changes (`input` for text fields and radios, `change` for selects). `data-herb-toggle="name"` flips a Boolean, `data-herb-set="editing=true"` on a button sets a literal on click. These work on helper-generated tags, so pass them through `data: { herb_set: ... }`.
- `hidden="<%= ... %>"` on a literal tag is added or removed as the state changes. Our CSS forces `[hidden] { display: none !important }`.

The [state](https://herb-tools.dev/language/state) and [actions](https://herb-tools.dev/language/actions) docs cover everything else.

## Rules of thumb

**Show and hide with `hidden`, not `<% if %>`.** A condition the client can evaluate (`==`, `!=`, `!`, `&&`, `||`, `>`, predicates like `blank?`) updates a boolean attribute (`hidden`, `disabled`, `required`, `checked`) in place. An `<% if %>` around Ruby output, like a form field, would need the server to render the branch, and the page would have to be fetched again.

**Swap field sets with a `<fieldset>` that is both `hidden` and `disabled`.** When two branches have fields with the same name (the league for a FIRST team versus a VEX team), hiding the inactive one isn't enough: it would still be submitted and its `required` fields would still block the form. A disabled fieldset's fields are neither submitted nor validated.

```erb
<fieldset class="contents" hidden="<%= selected_type != "first" %>" disabled="<%= selected_type != "first" %>">
  <%= form.select :league, ... %>
</fieldset>
```

**Bind attributes on literal tags.** The engine only sees attributes written in the template. `required: selected_type == "first"` inside a helper call is Ruby it can't keep current, so write the tag out and name it with the builder: `<input type="url" name="<%= form.field_name(:website_url) %>" id="<%= form.field_id(:website_url) %>" value="<%= form.object.website_url %>" required="<%= selected_has_website == "true" %>">`.

**Never read a state inside a helper call.** `<%= form.select :role, ..., selected: selected_role %>` makes the whole select depend on the state, which only the server can recompute. Read states in `hidden="..."`, `disabled="..."`, `<%= state %>` and simple conditions only.

**Name states `selected_<field>`, not after the field.** The `herb-state-valid-reads` lint rule looks for a state's name anywhere in an output tag, so a state called `role` trips on `form.label :role` and a state called `signee` trips on the text "Select a contract signee status". `selected_role` won't collide.

**Text that follows a state** is either the state itself (`<%= selected_currency %>`) or a condition with static branches:

```erb
<% if people == "1" %>person<% else %>people<% end %>
```

## Starting from a record

A state's default is a literal, or the name of one of the template's strict locals. Use a strict local to start from a record:

```erb
<%# locals: (affiliation:, form:, initial_type: affiliation.name.to_s) %>
<%# herb:slots client %>
<%# herb:state (selected_type: initial_type) %>
```

Page templates don't take locals, so state that starts from `@record` lives in a partial the page renders.

## Sharing state with a partial

A partial declares its own states. The caller binds one to its own with `state:`, and from then on they're one state:

```erb
<%# app/views/organizer_position_invites/_form.html.herb %>
<%# herb:state (selected_role: "member") %>
<%= render "organizer_position_invites/role_and_control_form", form:, state: { selected_role: selected_role } %>
<div hidden="<%= selected_role != "manager" %>">...</div>
```

Name the partial by its full path. The compiler opens it to check the binding.

## When JavaScript is still needed

Anything that is more than writing a value, like fetching a quote, counting words or moving DOM nodes, stays in a Stimulus controller. A controller can read and write the states around its element with `useState`, and gets a `<name>Changed` callback when one changes:

```js
import { Controller } from '@hotwired/stimulus'
import { useState } from 'reactionview'

export default class extends Controller {
  connect() {
    useState(this)
  }

  select({ params: { recipient } }) {
    this.state.set({ recipient_id: recipient.id, recipient_email: recipient.email })
  }

  recipient_idChanged(id) {
    // ...
  }
}
```

The runtime is started in `app/javascript/application.js` before Stimulus connects any controller, so `useState` always finds it.

### Cases that come from data

A condition the client evaluates has to be written in the template, like `selected_country != "CA"`. When the cases come from a model instead (wire fields per country, Wise fields per currency), use the `state-switch` controller. Each case names a state and the values it's shown for (`when`) or hidden for (`unless`). A case that doesn't match is hidden and disabled:

```erb
<div data-controller="state-switch">
  <% Event.countries_for_select.each do |code, _name| %>
    <% next if Wire.information_required_for(code).empty? %>
    <%= tag.fieldset hidden: code != initial_country, disabled: code != initial_country,
          data: { state_switch_target: "case", state_switch_name: "selected_country", state_switch_when: code } do %>
      ...
    <% end %>
  <% end %>
</div>
```

Render the starting `hidden` and `disabled` on the server, as above, so the page is right before the controller connects.

## Tooling

- `yarn lint:herb` checks herb views with the `herb-state-*` and `herb-slots-*` rules (`.herb.yml`).
- `bin/erb_lint` and Brakeman cover `.html.herb` too. Brakeman needs `--add-checks-path config/brakeman`, which CI and `bin/brakeman` pass.
- In tests, Herb raises on invalid nesting and unsafe attribute output, so a spec that renders a herb view fails on them.
