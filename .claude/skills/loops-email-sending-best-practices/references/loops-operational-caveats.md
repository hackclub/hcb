# Loops Operational Caveats

## Source URLs

- https://loops.so/docs/transactional
- https://loops.so/docs/transactional/attachments
- https://loops.so/docs/webhooks
- https://loops.so/docs/deliverability/transactional-group-inboxes
- https://loops.so/docs/deliverability/sending-from-multiple-domains
- https://loops.so/docs/contacts/double-opt-in
- https://loops.so/docs/api-reference/send-transactional-email
- https://loops.so/docs/api-reference/list-transactional-emails

## Marketing Vs Transactional Behavior

- In Loops, the Audience is a marketing-contact concept.
- Sending a transactional email to a new recipient does not add them to the Audience unless `addToAudience` is set to `true`.
- Sending transactional email to a new recipient does not trigger the normal "contact added" lifecycle path.
- Unsubscribed contacts can still receive transactional emails.
- Transactional emails do not include unsubscribe links and do not track opens or clicks.

## Attachments

- Attachments are not generally enabled by default in Loops; support must enable them for the account.
- Attachment payloads require `filename`, `contentType`, and base64 `data`.
- Loops documents a total JSON request size limit below 4 MB, with base64 overhead in mind.

## Webhooks

- Loops supports one webhook endpoint per account.
- Webhooks are signed and should be verified with the signing secret.
- Webhook dispatch is rate-limited to 10 events per second, with additional events queued.
- When double opt-in is enabled, certain contact webhooks are delayed until the contact confirms.

## Domain And Team Boundaries

- Multiple sending domains are modeled as separate Loops teams rather than one shared workspace.
- Settings, audiences, and related data do not automatically carry across teams.
- If the user wants separate communication types without splitting operational data, prefer lists and segmentation before proposing multiple domains.

## Group Inboxes

- Transactional email is intended for one-to-one delivery, not group inboxes.
- Group inboxes can silently block or moderate transactional email, especially in Google Workspace.
- If delivery to a group inbox matters, check moderation queues, email logs, and group posting policies before assuming the email provider failed.

## Practical Guidance

- If the recommendation depends on Loops product behavior, say so explicitly.
- If the user needs implementation details after the policy/best-practice decision is made, use the `loops-api` skill for the actual payloads and integration patterns.
