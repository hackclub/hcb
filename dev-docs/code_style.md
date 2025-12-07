# Code Style Guide

This document serves to instruct on how to style code for things the CI does not enforce. If the CI does not enforce a particular style and it is not mentioned here feel free to write it how you would like.

## Partials
There are some rules we are trying to enforce for partials. You may come across partials that do not follow these rules. Feel free to leave those alone but any new partials you write should follow by these rules.

### Render calls should use the full path

This makes it both easier to understand what is being rendered and also improves performance by reducing the amount of searching Rails needs to do.

**GOOD:**
```ruby
<%= render "events/nav" %>

<%= render "stripe_cards/stripe_card", stripe_card: @stripe_card %>
```
**BAD:**
```ruby
<%= render "nav" %>

<%= render @stripe_card %>
```

### Use strict locals instead of local_assigns or instance variables

Strict locals provide an easy to reference comment at the top of the file of which variables are needed. This will also raise an error if you forget to pass a variable, increasing the reliability of code written. If you have an optional local, you should still use strict locals but pass nil as the default value.

This is superior to instance variables because of the added rigidity to your code that it will fail immediately if a local is not passed. When you use instance variables, you don't always know that it will be defined depending on where the partial is rendered from.

**GOOD:**
```ruby
<%# locals: (example_local: "") %>

<%= example_local %>
```
**BAD:**
```ruby
<%= example_local %>
```

*Why use strict locals over local_assigns?*

Strict locals with nil defaults function similarly to local_assigns with the added benefit of raising an error if you forget to pass a local when no default is set.

## Presence
`presence` is a super useful function to return the object if it is present (not nil or blank); otherwise, it returns nil.

It is advised to use this function over using a ternary with `present?` to improve readability.

**GOOD:**
```ruby
@event_id = params[:event_id].presence
```
**BAD:**
```ruby
@event_id = params[:event_id].present? ? params[:event_id] : nil
```

## Capitalization
Most of the UI uses sentence case.

**GOOD:**
```ruby
"Get reimbursed"
```
**BAD:**
```ruby
"Get Reimbursed"
```

## Tables
If you have a column with an empty `<th>` tag, for example, a logo column, please put a comment inside of the `<th>` explaining what it is for.


**GOOD:**
```ruby
<tr>
  <th><%# icon %></th>
  <th>Status</th>
  <th>Date</th>
  <th>To</th>
  <th>For</th>
  <th class="text-right">Amount</th>
  <th><%# details button %></th>
</tr>
```
**BAD:**
```ruby
<tr>
  <th></th>
  <th>Status</th>
  <th>Date</th>
  <th>To</th>
  <th>For</th>
  <th class="text-right">Amount</th>
  <th></th>
</tr>
```
