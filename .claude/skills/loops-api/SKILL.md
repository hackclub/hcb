---
name: loops-api
description: >
  Use this skill whenever the user wants to integrate Loops from application
  code, backend services, webhook handlers, or server-side automation. This
  includes the Loops HTTP API and official SDKs for server-side contact,
  contact-property, mailing-list, event, API-key-validation,
  transactional-email, content editing (campaigns, groups, audience segments,
  email messages, themes, and components), workflow graph/node mutation,
  metrics, and inbound Loops webhooks. Trigger on phrases like "Loops API",
  "Loops SDK", "create a campaign via API", "update email message LMX",
  "create a theme via API", "create a workflow via API", "add a workflow node",
  "campaign metrics", "workflow group", "Loops webhook",
  "send a Loops event from my app", "add a contact to Loops in a webhook",
  "send a transactional email from backend code", or any time the user wants
  to integrate Loops into their app, backend, webhook, or automation. Do not
  trigger for CLI or shell-only requests.
metadata:
  version: 1.8.0
---

# Loops API and SDK Skill

This skill helps with Loops implementation workflows from application code. Use it for backend integrations, exact request guidance, and SDK or HTTP decisions.

## When To Use

Use this skill when the user needs to:

- integrate Loops into an app, backend, webhook, or automation
- decide between official SDKs and raw HTTP
- manage contacts, contact properties, mailing lists, events, or transactional email
- send transactional emails or create, edit, and publish transactional email templates via API
- manage contact suppression status/removal
- create draft campaigns with audience targeting (mailing list, segment, or filter), groups, and scheduling
- organize campaigns, transactional emails, and workflows into groups
- list or create audience segments for campaign/workflow targeting
- update email-message content (subject, sender, CC/BCC, format, fallbacks, LMX), send previews, and run Guardian checks
- list, create, update, and get themes and components to build LMX payloads
- upload images for email content
- create, update, inspect, and delete workflows and workflow nodes (including mailing-list changes, branches, reroutes, and queued-contact handling)
- fetch campaign, transactional, or workflow-node metrics
- list event patterns for workflow event triggers
- receive and verify inbound Loops webhooks (contact, email send, and engagement events)
- validate credentials or troubleshoot Loops request behavior from code

This skill is for implementation and operational usage, not broad email strategy or deliverability review.

## Working Style

When this skill is active:

1. Choose the right interface first: SDK or raw HTTP.
2. Prefer official SDKs for application code when the language has one.
3. Prefer raw HTTP only when no SDK is available or the user needs exact payload control.
4. Keep Loops requests server-side.
5. Verify exact behavior against the official docs or OpenAPI spec when details matter.
6. For LMX email design or brand work, use the theme/component endpoints in `references/http-api.md`; the LMX design policy lives in the `loops-lmx` skill.
7. If the task is primarily about Loops CLI install, auth, shell usage, or command help, use the separate `loops-cli` skill.

Official references:

- Docs: `https://loops.so/docs`
- API reference: `https://loops.so/docs/api-reference/intro`
- Campaign examples: `https://loops.so/docs/api-reference/examples/campaigns`
- JavaScript SDK: `https://loops.so/docs/sdks/javascript`
- Webhooks: `https://loops.so/docs/webhooks`
- OpenAPI spec: `https://app.loops.so/openapi.json`

## Choose The Interface

- SDK or HTTP API:
  - application code
  - backend services
  - webhook handlers
  - repeatable integrations
  Read `references/http-api.md`

If the user is working from the terminal instead of writing application code, use the `loops-cli` skill.

## Category Routing

- Auth, base URL, rate limits, contacts, suppression, properties, lists, events, uploads, inbound Loops webhooks, SDK examples, and HTTP errors:
  Read `references/http-api.md`
- Campaigns, campaign groups, transactional groups, workflow groups, audience segments, workflows, workflow nodes, event patterns, transactional emails, email messages, themes, components, metrics, and revision-safe updates:
  Read `references/http-api.md`. For LMX markup itself, also use the `loops-lmx` skill.

## Output Checklist

Aim to leave the user with:

- the right API interface choice for the task
- exact payload shapes or SDK usage
- any Loops-specific caveats that affect behavior
- the next validation step, such as a small test request or API-key check
