# Metabase

Hack Club uses [Metabase](https://www.metabase.com/) as a business intelligence
dashboard.

In order for Metabase to query HCB's data, it has access to our Postgresql
database.


**Scope of permissions:**

- Read only for **_specific_** tables.
- Metabase supports
  [`Actions`](https://www.metabase.com/docs/latest/databases/users-roles-privileges#privileges-to-enable-actions)
  and [Model Persistence](https://www.metabase.com/docs/latest/databases/users-roles-privileges#privileges-to-enable-model-persistence)
  which require write access to the database. At this point in time, I don't
  plan on granting write permissions until we find it necessary.


Here's a runbook for how the connection and Postgresql user was setup.


## Postgres User

- https://www.metabase.com/docs/latest/databases/users-roles-privileges
- https://devcenter.heroku.com/articles/heroku-postgresql-credentials#managing-permissions

1. On the Heroku dashboard, create a new database credentials named `metabase`.

2. Leave the Permissions setting as "No permissions".

   After the next step, the Heroku dashboard will show this credential has
   having "Custom permissions".

3. ```sql
   GRANT USAGE ON SCHEMA "public" TO metabase;
   ```

   This grants the `metabase` user permission to access the `public` schema, but
   not any tables inside the schema (yet) —
   [read more on why it's needed](https://stackoverflow.com/questions/17338621/what-does-grant-usage-on-schema-do-exactly).

4. Grant `SELECT` (read) access for **_specific_** tables.
   ```sql
   GRANT SELECT ON TABLE public.users TO metabase;
   ```

   Here are a list of tables granted with reasoning why:
   - `public.users`
     - Number of users
     - Number of teenagers
   - `public.user_sessions`
     - For determining whether a User is active using `last_seen_at`
   - `public.canonical_transactions`
   - `public.canonical_event_mapping`
   - `public.events`
   - `public.event_plans`
   - `public.disbursements`
     - Transactions raised
   - `public.organizer_positions`
   - `public.event_tags`
   - `public.event_tags_events`
     - Organizations with teenagers
   - `public.user_seen_at_histories`
     - Active users

