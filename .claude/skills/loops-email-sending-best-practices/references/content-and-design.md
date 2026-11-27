# Content And Design

## Source URLs

- https://loops.so/docs/creating-emails/sending-settings
- https://loops.so/docs/creating-emails/personalizing-emails
- https://loops.so/docs/creating-emails/styles
- https://loops.so/docs/creating-emails/using-templates
- https://loops.so/docs/creating-emails/font-support
- https://loops.so/docs/guides/email-dark-mode
- https://loops.so/docs/guides/html-emails
- https://loops.so/docs/creating-emails/uploading-custom-email

## Subject, Preview, And Sender Identity

- Keep subject lines concise. Loops recommends fewer than 50 characters and around 10 words.
- Use preview text intentionally; if you leave it empty, some inboxes will show the beginning of the email body instead.
- The sender name and from-address should be recognizable to the recipient.
- Set a reply-to when a different response path is useful; otherwise let replies route to the from-address.

## Personalization

- Personalize only with data that is reliable and useful.
- In Loops:
  - campaigns use contact properties (`{contact.*}`)
  - workflow/lifecycle emails use contact properties (`{contact.*}`) and event properties (`{event.*}`)
  - transactional emails use data variables (`{data.*}`)
- Always provide fallbacks for contact properties in campaigns and for contact and event properties in workflow emails. Loops warns that missing values can prevent the email from sending.
- Use personalization to add context, not to simulate familiarity where none exists.

## Layout And Design

- Start simple. Clear hierarchy, scannable copy, and obvious CTA usually outperform decorative complexity.
- In Loops, styled emails use a centered responsive column with a 600px max width; plain emails better mimic direct email-client messages.
- Use themes for consistency when multiple emails should share a branded system.
- Prefer readability and accessibility over novelty:
  - sufficient contrast
  - clear heading structure
  - language set correctly
  - restrained image use

## Dark Mode And Rendering

- Design assets so they survive both light and dark mode.
- Loops recommends logos that still work on dark backgrounds, often with a gray or colored mark rather than pure black.
- A stroke around a logo can help preserve contrast in dark mode.
- Loops automatically enables dark-mode support where email clients can handle it, but custom CSS for dark-mode-specific behavior requires imported MJML rather than the editor.

## Practical Review Heuristics

- Subject and preview are aligned rather than repeating each other.
- The first screen explains why the email matters.
- Links and buttons are obvious and not overloaded.
- Templates are fully de-placeholdered and all links are checked.
- Product-update and lifecycle emails stay brief and relevant instead of reading like changelog dumps.

## Loops-Specific Notes

- Dynamic content can be used in Loops sending settings fields, not just the body.
- For multi-language programs in Loops, store language on the contact, segment by it for campaigns/loops, and map transactional IDs by language.
- If custom HTML/CSS behavior is required, Loops expects MJML imports rather than arbitrary HTML email content in normal editor flows.
