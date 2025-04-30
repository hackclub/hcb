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


## Postgres User for Meteabase

1. Create a `metabase` User in the database.
```bash
su - postgres
psql
# Create metabase user
CREATE USER rails WITH INHERIT CONNECTION LIMIT 500 PASSWORD 'password here';
```

2. Configure permissions
   ```sql
   GRANT USAGE ON SCHEMA "public" TO metabase;
   ```

   This grants the `metabase` user permission to access the `public` schema, but
   not any tables inside the schema (yet) —
   [read more on why it's needed](https://stackoverflow.com/questions/17338621/what-does-grant-usage-on-schema-do-exactly).

3. Grant `SELECT` (read) access for **_specific_** tables.
   ```sql
   GRANT SELECT ON TABLE public.users TO metabase;
   GRANT SELECT ON TABLE public.user_sessions TO metabase;
   GRANT SELECT ON TABLE public.canonical_transactions TO metabase;
   GRANT SELECT ON TABLE public.canonical_event_mappings TO metabase;
   GRANT SELECT ON TABLE public.events TO metabase;
   GRANT SELECT ON TABLE public.event_plans TO metabase;
   GRANT SELECT ON TABLE public.disbursements TO metabase;
   GRANT SELECT ON TABLE public.organizer_positions TO metabase;
   GRANT SELECT ON TABLE public.event_tags TO metabase;
   GRANT SELECT ON TABLE public.event_tags_events TO metabase;
   GRANT SELECT ON TABLE public.user_seen_at_histories TO metabase;
   ```

   Here are a list of tables granted with reasoning why:
   - `public.users`
     - Number of users
     - Number of teenagers
   - `public.user_sessions`
     - For determining whether a User is active using `last_seen_at`
   - `public.canonical_transactions`
   - `public.canonical_event_mappings`
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

4. Grant access to Zach's Google Sheets integration for expense reporting.
   Fivetran writes to table(s) in the `google_sheets` schema and Metabase needs
   to be able to read from it.
   ```sql
   GRANT USAGE ON SCHEMA "google_sheets" TO metabase;
   GRANT SELECT ON TABLE "google_sheets.hcb_expense_reporting" TO metabase;
   ```

5. Follow the instructions in [bastion.md](bastion.md) to create a bastion user
   for Metabase.

## Fivetran (and it's Postgres user)

Zach uses Fivetran to sync Google Sheets into the HCB postgres database. To make
this happen, Fivetran needs read and write access to the HCB postgres.

**Scope of permissions:**
- Full read and write access to the `google_sheets` schema
- NO read nor write access to the `public` schema (where HCB's data is stored)

1. Create a `fivetran` User in the database.
```bash
su - postgres
psql
# Create metabase user
CREATE USER fivetran WITH INHERIT CONNECTION LIMIT 500 PASSWORD 'password here';
```

2. Configure permissions (give read/write to all tables in `google_sheets` schema)
   ```sql
   GRANT ALL PRIVILEGES ON SCHEMA google_sheets TO fivetran;
   GRANT all on all tables in schema google_sheets to fivetran;
   ```

3. Follow the instructions in [bastion.md](bastion.md) to create a bastion user
   for Metabase.
    - Fivetran will provide an SSH public key when you configure a Fivetran
      destination using "Connect via an SSH Tunnel".

~ @garyhtou
