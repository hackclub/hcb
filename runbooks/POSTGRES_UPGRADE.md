# Upgrading Postgres

## Why?

You are probably reading this because $INFRASTRUCTURE_PROVIDER (e.g. Heroku) is warning you that the current major version of Postgres is reaching [EOL](https://endoflife.date/postgresql) and that you must upgrade (e.g. [PG 12->13](https://github.com/hackclub/hcb/issues/4586#issue-2021498584) or [PG 11->12](https://github.com/hackclub/hcb/issues/3302#issue-1487260939)). Usually this is correlated to [PostgreSQL's official EOL policy](https://www.postgresql.org/support/versioning/).

In the current HCB setup, a Postgres major version upgrade requires downtime. So this runbook details the steps we take to set this downtime and do the upgrade.

## How?

1. Read through https://devcenter.heroku.com/articles/upgrading-heroku-postgres-databases and https://devcenter.heroku.com/articles/testing-postgresql-version-upgrades
2. Read the release notes between the latest release of the major version you are upgrading to and the version you are upgrading from on https://www.postgresql.org/docs/release/. You can aso use a page like https://why-upgrade.depesz.com/show?from=12.17&to=13.14 to collate all the changes. Typically Postgres maintains good backwards compatibility, but keep an eye out for any changes that may cause us problems.
3. Do the upgrade locally. Depending on your set up this may be as simple as changing the version in a `Dockerfile` and rebuilding. Run test suite and fix any issues that are broken due to the new Postgres version. The confidence this gives us depends on the current test coverage (currently low until https://github.com/hackclub/hcb/issues/4488 is completed).
4. Pick a date and time to run the upgrade. We aim for times with low traffic. Historically, Pacific Time evenings are a good option (especially Tuesday and Wednesday evenings). Also, we should do our best to avoid scheduled sidekiq jobs that won't run again for a while. There are a couple of ways to determine low-traffic periods:

   - Heroku metrics (look at the RPM rate)
   - Logtail (look at the request rate)
   - Check Fullstory

   According to https://devcenter.heroku.com/articles/upgrading-heroku-postgres-databases#upgrading-with-pg-upgrade

   > Performing a pg:upgrade requires app downtime on the order of 30 minutes. This method is supported for all Heroku Postgres plans except Essential-tier plans.

   and https://www.crunchydata.com/blog/examining-postgres-upgrades-with-pg_upgrade#how-long-does-pg_upgrade-take states < 30 min up to 200,000 tables.
   We should still give ourselves some buffer time up to an hour so that the process isn't rushed and to allow for fixing mistakes.

5. Announce the maintenance time at least a week in advance. Use whatever channels are appropriate. Some historical examples:

   - in-app banner e.g. https://github.com/hackclub/hcb/pull/5775
   - Post to HCB changelog e.g. https://changelog.hcb.hackclub.com/scheduled-maintenance-april-3rd-2024-289134
   - slack message e.g. https://hackclub.slack.com/archives/CN523HLKW/p1711500113145969

6. Do a dry run of the upgrade on staging (using a fork of the production database). See below for dry run steps.

7. During maintenance period, do the real production upgrade (see steps below)

## Dry run on staging

This is based heavily on https://github.com/hackclub/hcb/issues/3302#issuecomment-1695302481 which in turn is based on https://devcenter.heroku.com/articles/testing-postgresql-version-upgrades

1. **Staging only** Create a staging instance of bank specifically to test the database upgrade. The following creates a new app within the hackclub heroku team named `bank-staging-postgres-upgrade`.

   ```
   heroku apps:create bank-staging-postgres-upgrade -t hackclub
   ```

   Then visit the [`bank-hackclub` pipeline page](https://dashboard.heroku.com/pipelines/e61db6c3-496d-4233-ad3c-4a29752dcc12) and add `bank-staging-postgres-upgrade` to the staging column

   Set the appropriate buildpacks on this app (use the same order as defined in https://github.com/hackclub/hcb/blob/main/app.json or copy from the prod instance).

   ```bash
   heroku buildpacks:add -a bank-staging-postgres-upgrade "https://github.com/maxwofford/heroku-buildpack-sourceversion"
   heroku buildpacks:add -a bank-staging-postgres-upgrade "https://github.com/gaffneyc/heroku-buildpack-jemalloc.git"
   heroku buildpacks:add -a bank-staging-postgres-upgrade "https://github.com/nickrivadeneira/heroku-buildpack-apt#gobject-introspection-support"
   heroku buildpacks:add -a bank-staging-postgres-upgrade "https://github.com/dscout/wkhtmltopdf-buildpack.git"
   heroku buildpacks:add -a bank-staging-postgres-upgrade "heroku/nodejs"
   heroku buildpacks:add -a bank-staging-postgres-upgrade "heroku/ruby"
   heroku buildpacks:add -a bank-staging-postgres-upgrade "heroku/metrics"
   ```

   Copy the `RAILS_MASTER_KEY` environment variable (called [Config Vars in heroku](https://devcenter.heroku.com/articles/config-vars)) from prod to this staging app

2. **Staging only** [Fork the prod database](https://devcenter.heroku.com/articles/heroku-postgres-fork)

   ```
   heroku addons:create heroku-postgresql:standard-0 --fork bank-hackclub::DATABASE_URL --as PROD_DB_FORK -a bank-staging-postgres-upgrade

   heroku pg:wait -a bank-staging-postgres-upgrade
   ```

   This will take ~30 minutes.

3. **Staging only** Create a redis instance for the staging environment if there isn't one already, ~1 minute.
4. **Staging only** Attach `PROD_DB_FORK` to `bank-staging-postgres-upgrade` as `DATABASE` via the UI.

5. **Staging only** Deploy using the UI. Under the Deploy tab, in the "Manual deploy" section, deploy the `main` branch.

6. Verify you can access the website and login. Do some action that saves new data (e.g creating a disbursement).

7. Create a follower for `PROD_DB_FORK`

   ```
   heroku addons:create heroku-postgresql:standard-0 --follow bank-staging-postgres-upgrade::PROD_DB_FORK --as TEST_UPGRADE_FOLLOWER --app bank-staging-postgres-upgrade

   heroku pg:wait -a bank-staging-postgres-upgrade
   ```

   It may take a few minutes for heroku to accept this command if it thinks `PROD_DB_FORK` is too new. Creating the follower will take about 5-6 minutes.

8. Set maintenance mode page to database upgrade explanation `heroku config:set MAINTENANCE_PAGE_URL=<DATABASE_UPGRADE_URL> -a bank-staging-postgres-upgrade`. Past examples of `DATABASE_UPGRADE_URL` are https://changelog.hcb.hackclub.com/scheduled-maintenance-april-3rd-2024-289134 and https://postal.hackclub.com/w/ohsB1xRMhhuwbFeWwVihLQ.
9. Turn on maintenance mode with `heroku maintenance:on --app bank-staging-postgres-upgrade`
10. Verify the follower is caught up to primary with `heroku pg:info -a bank-staging-postgres-upgrade`

    ```
    === DATABASE_URL, PROD_DB_FORK_URL
    Plan: Standard 0
    <REDACTED>

    === TEST_UPGRADE_FOLLOWER_URL
    Plan: Standard 0
    <REDACTED>
    Following: PROD_DB_FORK
    Behind By: 0 commits
    ```

11. Upgrade the follower to `NEW_MAJOR_VERSION` (e.g. 13, 14) with

    ```
    heroku pg:upgrade TEST_UPGRADE_FOLLOWER --version <NEW_MAJOR_VERSION> --app bank-staging-postgres-upgrade

    heroku pg:wait -a bank-staging-postgres-upgrade
    ```

    This will take about 6 minutes.

12. Promote the follower, turn off maintenance and smoke test the app. We can verify that new writes only go to the upgraded, newly promoted database and not the old primary.

    ```
    heroku pg:promote TEST_UPGRADE_FOLLOWER --app bank-staging-postgres-upgrade
    ```

    Even if the above command finishes, it might take some time for the promotion to finish and for the app to reconnect. Try starting a heroku rails console and check you can connect to the database (e.g. `Disbursement.last`) before continuing.

    ```
    heroku maintenance:off --app bank-staging-postgres-upgrade
    ```

13. Use the HCB app to write something to the database (e.g. creating a disbursement). Then run psql on new primary vs old primary to verify the data is only in the new database.

    ```
    heroku pg:psql prod_db_fork -a bank-staging-postgres-upgrade

    heroku pg:psql -a bank-staging-postgres-upgrade
    ```

14. **Staging only** Tear down staging database instances, or delete `bank-staging-postgres-upgrade`, which should delete the affiliated databases.

    ```
    heroku addons:destroy PROD_DB_FORK --app bank-staging-postgres-upgrade
    heroku addons:destroy DATABASE --app bank-staging-postgres-upgrade
    ```

## Prod upgrade

This is based heavily on https://github.com/hackclub/hcb/issues/3302#issuecomment-1695321484 and https://devcenter.heroku.com/articles/upgrading-heroku-postgres-databases.

1. Communicate that you are starting the process so other HCB engineers and team members are aware (even if they should already know this because it is the start of the scheduled maintenance).

### The next 2 steps can be done in advance of the maintenance time

2. Create a follower for `DATABASE`.

   ```
   heroku addons:create heroku-postgresql:standard-0 --follow bank-hackclub::DATABASE --app bank-hackclub

   heroku pg:wait -a bank-hackclub
   ```

   It may take a few minutes for heroku to accept this command since the follower database is too new. Creating the follower after may take about 5-6 minutes.

3. Set maintenance mode page to database upgrade explanation `heroku config:set MAINTENANCE_PAGE_URL="<DATABASE_UPGRADE_URL>" -a bank-hackclub`. Past examples of `DATABASE_UPGRADE_URL` are https://changelog.hcb.hackclub.com/scheduled-maintenance-april-3rd-2024-289134 and https://postal.hackclub.com/w/ohsB1xRMhhuwbFeWwVihLQ.

### The next steps are to guarantee that there won't be any more writes to the database.

4. Turn on maintenance mode with `heroku maintenance:on --app bank-hackclub`
5. **prod only** Turn off preboot and scale down web and worker dynos
   ```
   heroku features:disable preboot -a bank-hackclub
   heroku ps:scale web=0 -a bank-hackclub
   heroku ps:scale worker=0 -a bank-hackclub
   ```
6. **prod only** Verify in Resources tab of the Heroku UI that all the dynos have scaled down to 0.
7. Verify the follower is caught up to primary with `heroku pg:info -a bank-hackclub`. You may have to wait a few minutes to make sure all the dynos from the above step are down and that the follower has fully caught up (i.e. `Behind by: 0 commits`).

   ```
   === DATABASE_URL
   Plan: Standard 0
   <REDACTED>

   === <FOLLOWER_DATABASE>_URL
   Plan: Standard 0
   <REDACTED>
   Following: DATABASE
   Behind By: 0 commits
   ```

### At this point there won't be any more writes to the database and the follower has fully caught up (i.e. is a 100% clone)

8. **prod only** Create a manual database backup on Heroku. In case something goes wrong, we can hopefully use this to restore the DB with the older Postgres version.

9. Upgrade the follower to `NEW_MAJOR_VERSION` (e.g. 13, 14) with

   ```
   heroku pg:upgrade <FOLLOWER_DATABASE> --version <NEW_MAJOR_VERSION> --app bank-hackclub

   heroku pg:wait -a bank-hackclub
   ```

   This takes about 6 minutes.

10. Promote the follower

    ```
    heroku pg:promote <FOLLOWER_DB_NAME> --app bank-hackclub
    ```

11. Scale number of web and worker dynos back and re-enable preboot

    ```
    $ heroku ps:scale web=2 -a bank-hackclub
    Scaling dynos... done, now running web at 2:Performance-M

    $ heroku ps:scale worker=1 -a bank-hackclub
    Scaling dynos... done, now running worker at 1:Performance-M

    $ heroku features:enable preboot -a bank-hackclub
    Enabling preboot for ⬢ bank-hackclub... done
    ```

12. Turn off maintenance mode and smoke test the app in browser. We can verify that new writes only go to the upgraded, newly promoted database and not the old primary.

    ```
    heroku maintenance:off --app bank-hackclub
    ```

    Run psql on new primary vs old primary

    ```
    heroku pg:psql DATABASE_URL -a bank-hackclub

    heroku pg:psql <OLD_PRIMARY_DB_NAME> -a bank-hackclub
    ```

13. **prod only** Reset maintenance mode to generic page

    ```
    heroku config:set MAINTENANCE_PAGE_URL=https://hackclub.github.io/hcb/maintenance-mode.html -a bank-hackclub
    ```

14. **prod only** A few days later, if there are no major issues, delete the old DB.
    N.B. On Heroku specifically, you may notice commit activity on the old database. This is [expected due to heroku automation](https://help.heroku.com/3C0QEC75/why-does-the-data-dashboard-show-commit-activity-on-an-unused-heroku-postgres-instance), but verify that the queries you are seeing match that by querying `pg_stat_activity`

    > Issue

    > The Data Dashboard for Heroku Postgres instances shows commit activity, under the I/O section, even when the database is not being used.
    
    > Resolution

    > This is expected behaviour. Postgres treats each executed SQL statement as being implicitly wrapped in a transaction, so SELECT 1; is treated as BEGIN; SELECT 1; COMMIT;. As a result, each time a statement is executed successfully xact_commit is incremented in pg_stat_database, which is what we use to determine the commit activity. As our monitoring tooling executes queries to check the health of your database, there will be a baseline level of commits being recorded.
