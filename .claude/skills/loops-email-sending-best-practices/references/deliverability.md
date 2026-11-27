# Deliverability

## Source URLs

- https://loops.so/docs/deliverability/optimization
- https://loops.so/docs/deliverability/improving-inbox-placement
- https://loops.so/docs/deliverability/sending-reputation
- https://loops.so/docs/deliverability/gaining-insights
- https://loops.so/docs/deliverability/sending-from-multiple-domains
- https://loops.so/docs/deliverability/sending-from-subdomain
- https://loops.so/docs/deliverability/sending-to-large-audience
- https://loops.so/docs/guides/what-is-bimi
- https://loops.so/docs/guides/what-is-dns
- https://loops.so/docs/sending-domain

## Core Guidance

- Inbox placement is affected by more than content alone. Treat sending domain, IP history, cadence, consent quality, sending volume, blocklists, and recent recipient engagement as one system.
- Set up domain authentication cleanly before diagnosing content issues. In Loops this means verifying the sending domain records Loops provides, including SPF, DKIM, and MX, and understanding how DMARC/BIMI fit into the broader setup.
- Prefer a sending subdomain over the root domain. Loops recommends subdomains like `mail.company.com`, `hey.company.com`, or `updates.company.com`.
- Avoid fragmenting traffic across many domains. Loops explicitly recommends a single well-established sending domain over multiple weak or occasional domains.
- If you must split communication types, prefer lists and preference management over multiple domains.
- Do not send cold email from your primary domain. Loops explicitly warns against using Loops for cold email, and prior cold-email use on a primary domain can damage current deliverability.
- Warm new sending reputation with expected, high-intent email first:
  - onboarding/welcome emails
  - essential transactional email
  - small sends to recent or active users
- Expand to older or less-engaged contacts gradually. Batch larger backfills and stop expanding if performance degrades.
- When domain records were just changed, allow propagation time before over-correcting.

## Large-Audience Sending

- For new or weak domains, do not begin with a broad blast to a cold audience.
- Start with new signups and recently active users because they are more likely to engage.
- In the Loops guidance, a welcome loop plus essential transactional email is the preferred warm-up path before larger campaigns.
- When importing a backlog of users, bias toward recent signups or recent logins first, then widen gradually.

## Signals To Watch

- Prefer outcome and health signals over vanity metrics:
  - bounce rate
  - unsubscribe rate
  - spam complaints
  - delivery errors
  - steady engagement from the right audience
  - product actions tied to the email
- Gmail spam reports are not surfaced directly in Loops, so Loops recommends setting up Google Postmaster for Gmail-specific reputation and spam-rate insight.
- Open rates are directionally useful at best. Use them cautiously and do not treat them as the main success metric.

## Loops-Specific Notes

- Loops has sending guardrails and may monitor sends for deliverability before release.
- Loops recommends one sending domain per team. Multiple domains mean separate Loops teams and no shared audience/settings.
- The sending domain page in Loops is the first place to verify domain record setup before doing deeper deliverability troubleshooting.
