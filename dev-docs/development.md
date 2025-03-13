## Development

We recommend using Docker to get an instance running locally. It should work out-of-the-box and is how most contributors work on HCB.

- [Development](#development)
  - [Quickstart with GitHub Codespaces](#quickstart-with-github-codespaces)
  - [Automated setup with Docker](#automated-setup-with-docker)
  - [Manual setup with Docker](#manual-setup-with-docker)
  - [Local setup](#local-setup)
- [Heroku tasks](#heroku-tasks)
- [Production Access](#production-access)

### Quickstart with GitHub Codespaces

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new?hide_repo_select=true&ref=main&repo=135250235&skip_quickstart=true&machine=premiumLinux&devcontainer_path=.devcontainer%2Fdevcontainer.json&geo=UsWest)

[GitHub Codespaces](https://docs.github.com/en/codespaces) allows you to run a development environment without installing anything on your computer, allows for multiple instances, creates an overall streamlined and reproducible environment, and enables anyone with browser or VS Code access to contribute.

To get started, [whip up a codespace](https://docs.github.com/en/codespaces/getting-started/quickstart), open the command palette(<kbd>CTRL</kbd>+<kbd>SHIFT</kbd>+<kbd>P</kbd>), and search `Codespaces: Open in VS Code Desktop`. HCB does not work on the web version of Codespaces. Run `bin/dev`. If you can't open the link that is printed in the terminal, ensure the `3000` port is public under the `PORTS` tab in your terminal.

After creating your codespace, run `bundle install` and `bin/rails db:migrate`. This will finish preparing HCB for development.

### Automated setup with Docker

If you are running macOS or Ubuntu, you can clone the repository and run the [docker_setup.sh](https://github.com/hackclub/hcb/docker_setup.sh) script to automatically setup a development environment with Docker. Append `--with-solargraph` to the command to also setup [Solargraph](https://solargraph.org), a language server for Ruby. You may also need to install the [Solargraph extension](https://github.com/castwide/solargraph#using-solargraph) for your editor.

```bash
./docker_dev_setup.sh
# or with Solargraph
./docker_dev_setup.sh --with-solargraph
```

Then, to start the development server:

```bash
./docker_start.sh
# or with Solargraph
./docker_start.sh --with-solargraph
```

### Manual setup with Docker

Copy .env file

```bash
cp .env.docker.example .env.docker
```

Run Docker

```bash
env $(cat .env.docker) docker-compose build
env $(cat .env.docker) docker-compose run --service-ports web bundle exec rails db:create db:migrate
env $(cat .env.docker) docker-compose run --service-ports web bundle exec rails s -b 0.0.0.0 -p 3000
```

(Optional) Run Solargraph in Docker

[Solargraph](https://solargraph.org/demo) is a tool that provides IntelliSense, code completion, and inline documentation for Ruby. You may also need to install the [Solargraph extension](https://github.com/castwide/solargraph#using-solargraph) for your editor.

```bash
env $(cat .env.docker) docker-compose -f docker-compose.yml -f docker-compose.solargraph.yml build
env $(cat .env.docker) docker-compose -f docker-compose.yml -f docker-compose.solargraph.yml up -d solargraph
```

### Local setup

Install [rbenv](https://github.com/rbenv/rbenv)

```bash
brew install rbenv
```

Install [bundler](https://bundler.io/)

```bash
gem install bundler -v 1.17.3
```

Run bundler

```bash
bundle install
```

Install yarn dependencies

```bash
yarn install
```

Create and migrate database

```bash
bundle exec rake db:drop db:create db:migrate
```

Populate the database

```bash
heroku git:remote -a bank-hackclub # if your repo isn't attached to the heroku app
heroku pg:backups:capture
heroku pg:backups:download # will save as latest.dump, double check to make sure that file is created
pg_restore --verbose --clean --no-acl --no-owner -d bank_development latest.dump
```

Run the application

```bash
bin/rails s
```

Browse to [localhost:3000](http://localhost:3000)

**Additional installs for local development:**

Install [wkhtmltopdf](https://wkhtmltopdf.org/)

```bash
brew install wkhtmltopdf
```

Install [ImageMagick](https://imagemagick.org/)

```bash
brew install imagemagick
```

## Heroku tasks

Please check app.json for the buildpacks required to run HCB on Heroku.

The `heroku/metrics` buildpacks allow us to record in depth Ruby specific
metrics about the application.
See [PR #2236](https://github.com/hackclub/hcb/pull/2236)
for more information.

The apt buildpack works in conjunction with the local Aptfile in order to
install poppler-utils. Poppler-utils helps generate preview thumbnails of
documents.

## Production Access

We've transitioned to using development keys and seed data in development, but historically have used production keys and data on dev machines. It is recommended to not roll back to using production data & keys in development, but if absolutely necessary the following steps can be taken:

- Set environment variables `DOPPLER_TOKEN=<a doppler token with production access>`, `DOPPER_PROJECT=hcb`, `DOPPLER_CONFIG=production` in your docker container (usually via `.env.development`). N.B. this does not set [`RAILS_ENV=production`](https://guides.rubyonrails.org/configuring.html#rails-environment-settings), which you should **never** do on a development machine.
- Put the production key in `config/credentials/production.key`. If you have heroku access you can get this from the `RAILS_MASTER_KEY` environment variable. If not then ask a team member (ping `@creds` in Slack). [DO NOT CHECK THIS INTO GIT](https://github.com/hackclub/hcb/blob/99fab73deb27a09a9424847e02080cb3ea5d09cf/.gitignore#L29)
    - If you need to edit [`config/credentials/production.yml.enc`](./config/credentials/production.yml.enc), you can now run `bin/rails credentials:edit --environment=production`.
- Run the [docker_setup.sh](https://github.com/hackclub/hcb/docker_setup.sh) script to set up a local environment with Docker using a dump of the production database.
