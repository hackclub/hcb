# Development

We recommend using Docker to get an instance running locally. It should work out-of-the-box and is how most contributors work on HCB.

- [Running HCB locally](#running-hcb-locally)
  - [Quickstart with GitHub Codespaces](#quickstart-with-github-codespaces)
  - [Automated setup with Docker](#automated-setup-with-docker)
  - [Manual setup with Docker](#manual-setup-with-docker)
  - [Native setup](#native-setup)
- [Credentials](#credentials)
- [Deployment](#deployment)
- [Production Data](#production-data)

Once HCB is running locally, login using the email `admin@bank.engineering`. Use Letter Opener (`/letter_opener`) to access the development email outbox and retrieve the login code.

## Running HCB locally

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
cp .env.development.example .env.development
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

### Native setup

Before beginning this process, please **ensure you have both Ruby and Node
installed**, as well as a PostgreSQL database running.

#### [Step 1] Prereq: Install Ruby and Node

See [`.ruby-version`](.ruby-version)
and [`.node-version](.node-version) for which versions you need installed. I
personally recommend using a version manager
like [rbenv](https://rbenv.org/), [nvm](https://github.com/nvm-sh/nvm),
or [asdf](https://asdf-vm.com/).

#### [Step 2] Prereq: Install and run PostgreSQL

We recommend you use version `15.12` as that's what running in production. If
you're on MacOS, I recommend using Homebrew to get Postgres up and running. If
you are on another OS or dislike Homebrew, please refer to one of the many
guides out there on how to get a simple Postgres database running for local
development.

**How to install Postgres using Homebrew**

```bash
brew install postgresql@15 # You only need to run this once
brew services start postgresql@15
```

#### [Step 3] HCB-specific instructions

Now that you have Ruby, Node, and Postgres installed, we can begin with the
HCB-specific setup instructions.

1. Clone the repository
   ```bash
   git clone https://github.com/hackclub/hcb.git
   ```

2. Set up your environment variables
   ```bash
   cp .env.development.example .env.development
   ```

   Since you're running HCB outside of Docker, you will need to update the
   `DATABASE_URL` environment variable located in `.env.development`. The
   default caters towards Docker and GitHub Codespaces users. Please update it to
   ```
   postgres://postgres@127.0.0.1:5432
   ```

3. Install ruby gems
   ```bash
   bundle install
   ```

4. Install node packages
   ```bash
   yarn install
   ```

5. Prepare the database
   This creates the necessary tables and seeds it with example data.
   ```
   bin/rails db:prepare
   ```

6. Run Rails server
   ```bash
   bin/dev
   ```
   Yay!! HCB will be running on port 3000. Browse to [localhost:3000](http://localhost:3000).

   Optionally, if you want to run HCB on a different port, try adding `-p 4000`
   to the command.

**Additional installs for local development:**

Install [wkhtmltopdf](https://wkhtmltopdf.org/)

```bash
# Mac specific instruction:
brew install wkhtmltopdf
```

Install [ImageMagick](https://imagemagick.org/)

```bash
# Mac specific instruction:
brew install imagemagick
```

## Credentials

We used [Doppler](https://www.doppler.com/) to manage our credentials; if you have access to Doppler, you can set a `DOPPLER_TOKEN` in your `.env` file. Otherwise, you can provide credentials via a `.env.development` file [(view example)](.env.development.example).

## Deployment

All pushes to the `main` branch are automatically deployed by Heroku. We also have staging deploys per PR/branch using Heroku pipelines.

### Staging Access

Login using the email `staging@bank.engineering`. Visit `#hcb-staging` on the [Hack Club Slack](https://hackclub.com/slack) for the code.

## Production Data

We've transitioned to using development keys and seed data in development, but historically have used production keys and data on dev machines. It is recommended to not roll back to using production data & keys in development, but if absolutely necessary the following steps can be taken:

- Set environment variables `DOPPLER_TOKEN=<a doppler token with production access>`, `DOPPER_PROJECT=hcb`, `DOPPLER_CONFIG=production` in your docker container (usually via `.env.development`). N.B. this does not set [`RAILS_ENV=production`](https://guides.rubyonrails.org/configuring.html#rails-environment-settings), which you should **never** do on a development machine.
- Put the production key in `config/credentials/production.key`. If you have heroku access you can get this from the `RAILS_MASTER_KEY` environment variable. If not then ask a team member (ping `@creds` in Slack). [DO NOT CHECK THIS INTO GIT](https://github.com/hackclub/hcb/blob/99fab73deb27a09a9424847e02080cb3ea5d09cf/.gitignore#L29)
    - If you need to edit [`config/credentials/production.yml.enc`](./config/credentials/production.yml.enc), you can now run `bin/rails credentials:edit --environment=production`.
- Run the [docker_setup.sh](https://github.com/hackclub/hcb/docker_setup.sh) script to set up a local environment with Docker using a dump of the production database.
