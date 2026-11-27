# Audience And Consent

## Source URLs

- https://loops.so/docs/contacts/double-opt-in
- https://loops.so/docs/contacts/email-blocklist
- https://loops.so/docs/contacts/mailing-lists
- https://loops.so/docs/contacts/filters-segments
- https://loops.so/docs/deliverability/maintaining-a-clean-list
- https://loops.so/docs/add-users/csv-upload

## Core Guidance

- Only send marketing email to recipients who clearly opted in.
- Use double opt-in when list quality or abuse risk matters. Loops positions double opt-in as a deliverability and list-quality improvement, especially for forms.
- Keep confirmation emails short, branded, and focused on the confirmation action.
- Maintain list hygiene at the source:
  - validate inputs
  - use captcha or bot protection
  - block disposable emails
  - avoid stale or low-intent imports
- A clean list improves deliverability by lowering bounce risk and reducing spam complaints from fake or abandoned addresses.

## Lists vs Segments

- Use segments for internal targeting logic.
- Use mailing lists when the subscriber should understand and control the category of communication they receive.
- In Loops, lists power the preference center and list-specific opt-in/out behavior.
- Keep public lists for discoverable opt-ins and preference control.
- Keep private lists for targeted internal grouping that should only be visible to subscribed contacts.

## Preference And Unsubscribe Management

- Make preference management easy and obvious for marketing email.
- In Loops, marketing emails automatically include a preference-center path, and MJML emails can use the `{unsubscribe_link}` tag.
- If the audience needs finer-grained choice, solve that with mailing lists and a preference center, not with multiple domains or hidden sending logic.

## Importing And Audience Expansion

- Do not treat old CSV imports as safe by default.
- When importing dormant users, bias toward recent or active cohorts first.
- In Loops CSV imports:
  - contacts are subscribed by default unless `Subscribed` is explicitly set to `false`
  - empty cells do not overwrite existing data
  - `null` is required to clear a field

## Loops-Specific Notes

- Loops automatically handles bounces, unsubscribes, and spam complaints.
- Double opt-in currently applies to Loops form endpoints, not to the API create/update contact endpoints.
- Pending double-opt-in contacts do not trigger normal contact webhooks until they confirm.
