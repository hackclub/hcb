# Accessing the Rails console

To log into the Rails console in production, run:

```bash
heroku console -a bank-hackclub
```

We can also replace `bank-hackclub` with any other app name (like a review app) to get the console for that app instead.

## Helpful commands

### Import database dump from Heroku

```
$ heroku git:remote -a bank-hackclub # if your repo isn't attached to the heroku app
$ heroku pg:backups:capture
$ heroku pg:backups:download # will save as latest.dump, double check to make sure that file is created
$ docker-compose run --service-ports web /bin/bash # enter the docker container, which includes pg_restore pre-installed
$ pg_restore --verbose --clean --no-acl --no-owner -h db -U postgres -d bank_development latest.dump
```

### Running migrations

Migrations are [automatically run on deployment to Heroku](https://github.com/hackclub/hcb/commit/d8eefe44dc9b2503ae1c42805681ad338dc89de1).

If for some reason you need to manually manage (or rollback) migrations, you can do so by running:

```bash
$ heroku run /bin/bash -a bank-hackclub
$ rails db:migrate:status
$ rails db:migrate # if you need to run migrations manually
$ rails db:rollback # if you need to rollback in production
```

### Running tests

```bash
bundle exec rspec
```
