# 2022-05-25 Post-mortem for Rails 6 -> 6.1 upgrade & deploy

_Written by @maxwofford_

I upgraded our Rails version in this PR: https://github.com/hackclub/hcb/pull/2588

What I did to test that everything worked before merge:
- Passing tests
- Went through the Rails upgrade documentation for 6.1
	- Went through the deprecation notices for 6.1
- Added mailer previews to check
- Used HCB locally to…
	- Invite users
	- Go through user-facing pages
	- Test signin (ie. sessions created on 6 should work after upgrade)

Deployment:
I watched the logs on deployment, and while the build succeeded, a couple things went wrong in production. Here’s the list of things I checked and fixed
- Migrations ran fine (hooray!)
- Queued jobs & watched logs to ensure regular jobs were sending fine (some were, but emails were failing)
- Logs showed Active Storage now expected the “image_processing” gem
	- This wasn’t listed in the rails upgrade guide, and wasn’t caught locally because our Active Storage variant code was walled to only run in production https://github.com/hackclub/hcb/blob/fb2007f6afd5dbc78f80276d53b8f441c3fee5da/app/helpers/users_helper.rb#L18
	- This was fixed in https://github.com/hackclub/hcb/commit/c26a78bae964deca52bfc0e8caeebf10953fc138
- Mail was failing to send
	- Not caught by tests because production specific configuration was missing
	- https://github.com/hackclub/hcb/commit/742c3e4e5ac8321f5880737e9fbc3cccf00a7e37
- Deprecation warnings for image variant code
	- This was an oversight on my part– the Rails deprecation list included this, but I didn’t see it. It wasn’t caught in development because the code was walled to production (mentioned above)
	- https://github.com/hackclub/hcb/commit/fb2007f6afd5dbc78f80276d53b8f441c3fee5da
- Admin pages broken
	- This was an oversight on my part– I didn’t check the admin pages in development, only pages for regular users
	- This was also listed in the deprecation notice, but not as simple as a “find and replace”
	- https://github.com/hackclub/hcb/commit/183091efcb78adbc4a0978e006080361508b0fb4
- CSS not loading
	- Caused by this bug: https://github.com/romanbsd/heroku-deflater/issues/54
	- This was hard to google for: https://heroku-app97991095.airbrake.io/projects/288439/groups/3281516312042108669?tab=overview
	- I was having other issues running `rails assets:precompile` which made it hard to find what the root problem was. Eventually I SSH’ed into the Heroku dyno & realized the precompiled assets were generated correctly, but accessing them from the web server was the issue
	- I think this could have been caught by trying to precompile or run the production version of HCB locally
	- https://github.com/hackclub/hcb/commit/fb548b8940bb5c690e4bcf8e0f12ff187b4b7442

Outcomes / downtimes:
- HCB now runs on Rails 6.1
- Some emails were delayed between [initial deploy](https://github.com/hackclub/hcb/commit/c4835b0520a74e02ca748fbf9693e35d08b2360e) and [fixing the production hostname](https://github.com/hackclub/hcb/commit/742c3e4e5ac8321f5880737e9fbc3cccf00a7e37) deploying (~10:25 am edt - ~10:46 am edt). Emails eventually retried and succeeded, so I didn't make an announcement about this.
- Assets (css, js) didn't load properly in production between [initial deploy](https://github.com/hackclub/hcb/commit/c4835b0520a74e02ca748fbf9693e35d08b2360e) and [removing heroku-deflater](https://github.com/hackclub/hcb/commit/fb548b8940bb5c690e4bcf8e0f12ff187b4b7442) (~10:25 am edt - ~12:02 pm edt). We use caching, so not all regular users online were affected, but non-users on HCB (ie. using the [donation page](https://hcb.hackclub.com/donations/start/hq) or visiting a transparent org) would load the page without CSS.
- During our concurrent deploys we maxed out our PG connections and failed to respond to a single Stripe Issuing webhook. Our authorization defaults to reject transactions if we don't respond to Stripe within 2 seconds, so a user's HCB card failed their charge. I'm reaching out to the affected user today.

Takeaways:
- Most of the issues from the upgrade were things that weren’t caught in development or testing. Previously that sort of thing would be caught in staging apps, but with [those turned off](https://status.heroku.com/incidents/2413) we need to make more of an effort of checking in prod before deployment.
- Dual booting rails might be good for this sort of thing– it’d make rolling back much easier b/c it’d just be an ENV variable switch.
- Checking the rails upgrade guide isn't enough to catch everything– each gem has their own changes & potential breaking changes.
- More of a heads up to the team that I'm going to be rolling out a large deploy– most of these issues could have been fixed in parallel & it would have reduced our downtime.

Leftover tasks:
- I removed heroku-deflater in the moment while trying to restore production, but didn’t search for a replacement. It’d be nice to get something else for serving gz assets.
- After a week or two (once we're sure 6.1 is running and stable), switch the non-reversible framework defaults [here](https://github.com/hackclub/hcb/blob/5312e0dc3886da0144a3024f72c4e18976c33b6f/config/initializers/new_framework_defaults_6_1.rb#L22-L32)
- This PR bumped rubocop, which changed a lot of it's checks. Formatting debt was dumped in here: https://github.com/hackclub/hcb/blob/5312e0dc3886da0144a3024f72c4e18976c33b6f/.rubocop_todo.yml
