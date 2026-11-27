# Email Types And Program Strategy

## Source URLs

- https://loops.so/docs/types-of-emails
- https://loops.so/docs/guides/lifecycle-emails
- https://loops.so/docs/guides/onboarding-emails
- https://loops.so/docs/guides/product-updates
- https://loops.so/docs/guides/open-rates
- https://loops.so/docs/deliverability/understanding-email-open-rates

## Choose The Right Email Type

- Campaign:
  - one-off send
  - same message to a segment or broad audience
  - good for newsletters, product updates, investor updates, feedback asks
- Loop / lifecycle automation:
  - triggered by contact changes or events
  - good for onboarding, activation, retention, re-engagement, dunning, and check-ins
- Transactional:
  - triggered by a specific user action
  - good for password resets, confirmations, receipts, shipping, login links
  - should not be used for promotional messaging

## Lifecycle Program Design

- Think in lifecycle stages rather than isolated emails:
  - acquisition
  - onboarding
  - retention
  - re-engagement
  - dunning
  - re-activation
- In Loops, the common pattern is one loop per lifecycle state, often keyed by a custom contact property such as `subscriptionStatus`.
- Favor triggers tied to real product state changes instead of arbitrary schedules whenever possible.

## New-Sender Strategy

- Start with an onboarding welcome loop and essential transactional email before broad campaigns.
- Expected, requested email is the safest early traffic because engagement is naturally high.
- After a few days of healthy warm-up, begin with small campaigns to recent or active users rather than the full historical audience.
- For first campaigns, Loops specifically recommends useful product updates or feature announcements over generic promotions or giveaways.

## Product Updates

- Product updates usually work best as concise recurring campaigns.
- Loops recommends:
  - roughly monthly cadence, unless shipping cadence justifies more
  - 2-3 relevant updates rather than long lists
  - a clear intro and path to the full changelog
  - relevance over completeness
- For established senders who have not emailed this format before, start with active users rather than the whole database.

## Measurement

- Open rates are noisy and increasingly inflated by privacy behavior in major mail clients.
- Do not optimize the program around opens alone.
- Prefer KPI framing tied to business outcomes:
  - trial starts
  - activation
  - conversion
  - reactivation
  - feature usage
  - unsubscribe and complaint trends

## Loops-Specific Notes

- Transactional emails in Loops do not track opens or clicks.
- Transactional emails do not require unsubscribe links.
- If the question is really about wiring triggers, data variables, or API payloads, hand off to the `loops-api` skill after the best-practice recommendation is clear.
