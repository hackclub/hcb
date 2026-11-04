# Instructions for coding agents

Read [`dev-docs/development.md`](dev-docs/development.md) for setup and [`dev-docs/code_style.md`](dev-docs/code_style.md) for conventions.

## Never reset, drop, or switch the development database

In this devcontainer, `DATABASE_URL` is exported globally and points at `bank_development`. Rails lets a database URL override the per-environment `database:` key in `config/database.yml`, so **`RAILS_ENV=test` still connects to `bank_development`**. Running test-environment database tasks therefore wipes the developer's seeded development data, not a test database.

Do **not** run any of these unless the user explicitly asks for that exact command in this conversation:

- `RAILS_ENV=test bin/rails db:*` (`db:prepare`, `db:reset`, `db:drop`, `db:create`, `db:schema:load`, `db:test:prepare`, `db:test:load`, `db:setup`, `db:seed`)
- `bin/rails db:reset`, `db:drop`, `db:schema:load`, `db:setup`, or `db:seed` in any environment
- `rake db:*` equivalents of the above
- Changing `DATABASE_URL`, `RAILS_ENV`, or `config/database.yml` to point the app at a different database

`bin/rails db:migrate` (forward only, development environment) is fine.

### Running specs safely

`spec/rails_helper.rb` calls `ActiveRecord::Migration.maintain_test_schema!`, which **purges and reloads the connected database** whenever the schema is out of date. With the global `DATABASE_URL`, that connected database is `bank_development`.

Before running `bundle exec rspec`, point it at a dedicated test database by overriding the URL for that command only:

```bash
DATABASE_URL="${DATABASE_URL%/*}/bank_test" bundle exec rspec spec/path/to/some_spec.rb
```

If `bank_test` does not exist or needs a schema, create and load it with the same override, never without it:

```bash
DATABASE_URL="${DATABASE_URL%/*}/bank_test" RAILS_ENV=test bin/rails db:create db:schema:load
```

If a spec run or database task fails for a reason that looks like it needs a reset, stop and tell the user instead of resetting.
