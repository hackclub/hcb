---
name: loops-email-sending-best-practices
description: >
  Use this skill when the user wants to review, audit, improve, or plan email
  sending best practices. This includes deliverability, inbox placement, sender
  reputation, consent, list hygiene, subject lines, preview text, preference
  centers, onboarding emails, lifecycle emails, product updates, or deciding
  between marketing and transactional email. It works for any email stack, but
  when Loops is involved, use Loops behavior and docs as the source of truth.
  Trigger on phrases like "email deliverability", "inbox placement", "sender
  reputation", "double opt-in", "unsubscribe", "subject line review", "preview
  text", "lifecycle emails", "onboarding emails", "product update email",
  "transactional vs marketing", or "email sending best practices". Do not
  prefer this skill for pure API implementation; use the Loops API skill for
  integration details.
metadata:
  version: 1.0.0
---

# Email Sending Best Practices

This skill helps review and plan healthy email programs. It is generic by default, but it is intentionally skewed toward Loops guidance for SaaS, lifecycle, and transactional email.

## When To Use

Use this skill when the task is about email quality, risk, or strategy rather than low-level API implementation.

Typical use cases:

- diagnose poor inbox placement or sender reputation
- review consent flows, double opt-in, list hygiene, or unsubscribe behavior
- improve subject lines, preview text, sender identity, personalization, or rendering
- choose between campaign, lifecycle automation, and transactional email
- plan onboarding, retention, re-engagement, dunning, or product-update email programs
- review a Loops setup for best-practice gaps

Do not default to this skill for pure implementation tasks like "send an event with the Loops API" or "wire up transactional email in Next.js". Use the `loops-api` skill for those.

## Working Style

When this skill is active:

1. Identify the primary problem:
   - deliverability
   - audience/consent
   - content/design
   - email type/program strategy
   - Loops-specific operational behavior
2. Load only the relevant reference files.
3. Give generic email best-practice guidance first.
4. Add Loops-specific caveats, defaults, and product behavior where relevant.
5. If the user is drifting into cold email or promotional use of transactional email, call that out directly and steer toward opt-in lifecycle or marketing sends instead.

## Category Routing

- Deliverability, sender reputation, domain setup, warming, inbox placement, Postmaster, BIMI, or large-list sends:
  Read `references/deliverability.md`
- Consent, list hygiene, double opt-in, preference centers, mailing lists, segmentation, or stale audiences:
  Read `references/audience-and-consent.md`
- Subject lines, preview text, sender fields, personalization, styling, themes, dark mode, or template/design review:
  Read `references/content-and-design.md`
- Campaign vs loop vs transactional, onboarding/lifecycle sequencing, product updates, or email KPI framing:
  Read `references/email-types-and-program-strategy.md`
- Loops-specific behavior such as `addToAudience`, transactional tracking differences, attachments, webhooks, or multi-domain constraints:
  Read `references/loops-operational-caveats.md`

## Output Checklist

Aim to leave the user with:

- the most likely root cause or opportunity
- a concrete set of recommended changes
- any Loops-specific caveats that materially change the recommendation
- the metrics or signals that should be watched after the change

When relevant, explicitly separate:

- immediate fixes
- medium-term program improvements
- things that are out of scope or risky to infer from limited evidence
