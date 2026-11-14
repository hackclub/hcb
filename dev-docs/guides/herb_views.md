# Herb views

Every HTML view is compiled by [Herb](https://herb-tools.dev) through [ReActionView](https://reactionview.dev) instead of Rails' default ERB handler (`config/initializers/reactionview.rb`). Herb reads the HTML and the Ruby together, so a view with a mismatched tag, an `<% if %>` that opens a tag in one branch and closes it in another, or a `<div>` inside a `<p>` fails to compile. In tests it also fails on unsafe output such as `<%= "disabled" if x %>` in attribute position. Write `<% if x %>disabled<% end %>` instead.
