# Long-running jobs

Background jobs on HCB run on Sidekiq, and Sidekiq restarts on every deploy. This guide covers what a restart does to a job that's still running, and how to write jobs that make progress anyway.

## What a restart does to a running job

When Sidekiq gets `SIGTERM`, it stops picking up new jobs and gives running jobs its shutdown timeout (25 seconds, the default) to finish. After that it pushes every job that's still running back onto its queue and raises `Sidekiq::Shutdown` in its thread. Once Sidekiq is back up, those jobs run again **from the start**.

So any job that runs longer than about 25 seconds can be cut off by a deploy, and a job that runs for many minutes can be cut off again and again if deploys keep landing during it. Nothing is lost, since the job is always requeued, but it may not finish until deploys quiet down, and its work so far is redone.

Interrupted runs don't show up as errors. If a scheduled job must finish, give it a [cron check-in](#cron-check-ins).

## Rules for writing jobs

1. **Prefer short jobs.** Work that finishes in a few seconds is never interrupted. If the work is naturally per record (per user, per transaction), consider enqueuing a small job per record instead of looping in one big job.
2. **Make jobs safe to run more than once.** Sidekiq guarantees a job runs at least once, not exactly once. An interrupted job reruns, so its side effects (emails, API calls, money movement) need to be idempotent or guarded.
3. **For long jobs, use continuations** (below) so a restart pauses the job instead of throwing its progress away.
4. **Never rescue `Exception`.** `Sidekiq::Shutdown` and `ActiveJob::Continuation::Interrupt` both inherit from `Exception`, not `StandardError`. `rescue Exception`, `discard_on Exception` or `retry_on Exception` will catch them, report a restart as an error, and break continuations. Use `StandardError` (a bare `rescue => e` already does).

## Continuations

Rails 8.1's [`ActiveJob::Continuable`](https://edgeapi.rubyonrails.org/classes/ActiveJob/Continuable.html) splits a job into steps, each with an optional cursor. At every checkpoint the job asks the queue adapter whether Sidekiq is shutting down. If it is, the job re-enqueues itself with its progress, and the next execution resumes from the saved step and cursor.

```ruby
class ExampleSweepJob < ApplicationJob
  include ActiveJob::Continuable

  def perform
    step :sweep do |step|
      User.where(...).find_each(start: step.cursor) do |user|
        do_something(user)
        step.advance! from: user.id # checkpoint
      end
    end

    step :notify # runs after :sweep completes; step boundaries are checkpoints too
  end
end
```

Continuations need a Sidekiq whose ActiveJob adapter implements `stopping?` (Sidekiq 8.0.5 or later). On older versions every checkpoint raises `NoMethodError`.

Things to get right:

- **Checkpoint often.** Progress is only saved when the job interrupts itself at a checkpoint. If the work between two checkpoints takes longer than the shutdown timeout, Sidekiq kills the job mid-step and it resumes from wherever it last re-enqueued itself. Keep each unit of work under about 20 seconds. A single long call, such as auto-paginating an entire API listing, has to become a cursor over pages.
- **Errors resume by default.** `resume_errors_after_advancing` defaults to `true`, so a `StandardError` raised after the job has made progress re-enqueues the job instead of failing it, with no limit unless `max_resumptions` is set. If the job raises on purpose (for example a failure-tolerance check), set `self.resume_errors_after_advancing = false`.
- **Carry run-wide state in the cursor.** Local variables reset on every execution. If the job tallies something across the whole run, keep it in the cursor (for example `step.set!([user.id + 1, processed, failed])`).
- **Don't checkpoint inside a database transaction.** An interrupt raised inside `transaction do ... end` rolls it back.
- **Resumed runs can overlap scheduled ones.** A resumed job waits 5 seconds before running again, so with a frequent cron schedule it can run alongside the next scheduled run. Per-record work must tolerate that, which rule 2 already requires.

Testing: `require "active_job/continuation/test_helper"` and include `ActiveJob::Continuation::TestHelper`. `interrupt_job_during_step(JobClass, :step, cursor: ...)` and `interrupt_job_after_step(JobClass, :step)` interrupt a job at a precise point so you can assert it resumes correctly. See `spec/jobs/user/update_card_locking/recurring_job_spec.rb`.

### Why continuations

| Option | Why or why not |
|---|---|
| `ActiveJob::Continuable` | Chosen. Built into Rails and stays inside ActiveJob, so `ApplicationJob`, `discard_on` and the test adapter keep working. Steps fit multi-step jobs like the transaction engines. |
| [`job-iteration`](https://github.com/Shopify/job-iteration) | Already in the bundle (via `maintenance_tasks`) and works on older Sidekiq, but each job iterates a single enumerator, which is awkward for multi-step pipelines. |
| `Sidekiq::IterableJob` | Saves its cursor every few seconds even on a hard kill, but it's a plain Sidekiq job: no ActiveJob callbacks, `discard_on` or test adapter, and no steps. |
| [`acidic_job`](https://github.com/fractaledmind/acidic_job) | Stores per-step progress in Postgres, but it's still a release candidate, adds tables and a serializable transaction per run, and doesn't detect shutdown. |
| [Temporal](https://temporal.io/) and similar | New infrastructure and a new programming model (deterministic workflows). More than this problem needs. |
| Sidekiq Enterprise rolling restarts | Lets the old process finish its jobs, but long jobs would keep several old-code processes running at once. Paid. |

## Cron check-ins

For scheduled jobs that must complete, wrap the work in an AppSignal cron check-in:

```ruby
def perform
  Appsignal::CheckIn.cron("transaction_engine_nightly_job") do
    # ...
  end
end
```

AppSignal only sends the finish event when the block returns, so a scheduled run that's interrupted, fails, or never runs shows up as a missed check-in. Name the check-in after the job's key in `config/schedule.yml`, and put it in the job (the scheduled unit), not in the services it calls, so ad-hoc runs from the console don't count as scheduled runs. To run one by hand and have it count, use `SomeJob.perform_now`.

## Shutdown timeout and cron

Raising Sidekiq's shutdown timeout gives jobs more time to finish, but it also pauses all job processing for longer on every deploy, and it lengthens the time the sidekiq-cron poller is down. sidekiq-cron skips any scheduled run whose time passed more than `reschedule_grace_period` (60 seconds by default) before it next polls. Don't raise the timeout without also raising the grace period.

## Status

| Job | Status |
|---|---|
| `PendingTransactionEngine::NightlyJob`, `TransactionEngine::NightlyJob` | Cron check-ins added. |
| Sidekiq 8 upgrade (needed for continuations) | In progress. |
| `User::UpdateCardLocking::RecurringJob` | Continuation in progress: one checkpoint per user. |
| `PendingTransactionEngine::NightlyJob` | Planned: one step per import and canonize stage; the Stripe authorization import pages with a cursor; the donation import uses a `find_each` cursor. |
| `TransactionEngine::NightlyJob` | Planned: measure per-step timing first, then isolated steps for the Plaid, Stripe and Column imports with cursors per bank account and per report. |
| Other long jobs (ledger assertions, Loops sync, session cleanup, stats, exports) | Later, as needed. |
