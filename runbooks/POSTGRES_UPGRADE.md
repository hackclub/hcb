# Upgrading Postgres

## Why?

You are probably reading this because $INFRASTRUCTURE_PROVIDER (e.g. Heroku) is warning you that the current major version of Postgres is reaching [EOL](https://endoflife.date/postgresql) and that you must upgrade (e.g. [PG 12->13](https://github.com/hackclub/hcb/issues/4586#issue-2021498584) or [PG 11->12](https://github.com/hackclub/hcb/issues/3302#issue-1487260939)). Usually this is correlated to [PostgreSQL's official EOL policy](https://www.postgresql.org/support/versioning/).

In the current HCB setup, a Postgres major version upgrade requires downtime. So this runbook details the steps we take to set this downtime and do the upgrade.

## How?

1. 
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
