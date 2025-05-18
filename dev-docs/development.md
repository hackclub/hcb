# Development

We recommend using Docker to get an instance running locally. It should work out-of-the-box and is how most contributors work on HCB.

- [Running HCB locally](#running-hcb-locally)
  - [Quickstart with GitHub Codespaces](#quickstart-with-github-codespaces)
  - [Automated setup with Docker](#automated-setup-with-docker)
  - [Manual setup with Docker](#manual-setup-with-docker)
  - [Native setup](#native-setup)
- [Testing](#testing)
- [Credentials](#credentials)

## Running HCB locally

Once HCB is running locally, log in into your local instance using the email `admin@bank.engineering`. Use Letter Opener (`/letter_opener`) to access the development email outbox and retrieve the login code.

### Quickstart with GitHub Codespaces

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new?hide_repo_select=true&ref=main&repo=135250235&skip_quickstart=true&machine=premiumLinux&devcontainer_path=.devcontainer%2Fdevcontainer.json&geo=UsWest)

[GitHub Codespaces](https://docs.github.com/en/codespaces) allows you to run a development environment without installing anything on your computer, allows for multiple instances, creates an overall streamlined and reproducible environment, and enables anyone with VS Code to contribute.

To get started, [whip up a codespace](https://docs.github.com/en/codespaces/getting-started/quickstart), open the command palette(<kbd>CTRL</kbd>+<kbd>SHIFT</kbd>+<kbd>P</kbd>), and search `Codespaces: Open in VS Code Desktop`. HCB does not work on the web version of Codespaces.

You can then run `bin/dev` to launch HCB. If you can't open the link that is printed in the terminal, navigate to the `PORTS` tab in your terminal and set port `3000` to public and then back to private.

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

#### [Step 1] Prerequisite: Install Ruby and Node

See [`.ruby-version`](/.ruby-version)
and [`.node-version`](/.node-version) for which versions you need installed. I
personally recommend using a version manager
like [rbenv](https://rbenv.org/) for ruby, [nvm](https://github.com/nvm-sh/nvm) for node,
or [asdf](https://asdf-vm.com/) for both.

#### [Step 2] Prerequisite: Install and run PostgreSQL

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

Install [ImageMagick](https://imagemagick.org/)

```bash
# Mac specific instruction:
brew install imagemagick
```

## Testing

### Automated testing w/ RSpec

HCB has a limited set of tests created using [RSpec](https://rspec.info/). Run them using:

```bash
bundle exec rspec
```

### Staging access

All PRs are deployed in a staging enviroment using Heroku. Login using the email `staging@bank.engineering`. Visit `#hcb-staging` on the [Hack Club Slack](https://hackclub.com/slack) for the code.

## Credentials

External contributors should provide credentials via a `.env.development` file [(view example)](/.env.development.example). Developers using the `devcontainer` setup (eg. in GitHub Codespaces), will need to rebuild the container after modifying the `.env.development` file to pull in the new variables.

HCB relies on two services for the majority of its financial features: Stripe and Column. Follow [the Stripe testing guide](./stripe_testing.md) to setup Stripe. You can register for a Column account [here](https://dashboard.column.com/register); after their onboarding questions, select "Skip to Sandbox".

We also include OpenAI and Twilio keys in our `.env.development` file. Information about obtaining these keys is available in these articles on [help.openai.com](https://help.openai.com/en/articles/4936850-where-do-i-find-my-openai-api-key) and [twilio.com](https://www.twilio.com/docs/iam/api-keys/keys-in-console).

Internally, we use [Doppler](https://www.doppler.com/) to manage our credentials; if you have access to Doppler, you can set a `DOPPLER_TOKEN` in your `.env` file to load in credentials from Doppler.

### Production data

We've transitioned to using development keys and seed data in development, but historically we have used production keys and data on development machines. We do not recommend rolling back to using production data & keys in development, but if absolutely necessary a HCB engineer can take the following steps:

- Use a `DOPPLER_TOKEN` with development access, this can be generated [here](https://dashboard.doppler.com/workplace/2818669764d639172564/projects/hcb/configs/development/access).

- Override the `LOCKBOX`, `ACTIVE_RECORD__ENCRYPTION__DETERMINISTIC_KEY`, `ACTIVE_RECORD__ENCRYPTION__KEY_DERIVATION_SALT`, and `ACTIVE_RECORD__ENCRYPTION__PRIMARY_KEY` secrets by defining them in `.env.development`. Use the values from the [`production` enviroment in Doppler](https://dashboard.doppler.com/workplace/2818669764d639172564/projects/hcb/configs/production).

- Run the [docker_setup.sh](https://github.com/hackclub/hcb/docker_setup.sh) script to set up a local environment with Docker. The script will use a dump of our production database from Heroku.

## Flipper

[Flipper](https://github.com/flippercloud/flipper) is used to toggle feature flags on HCB. Flipper can be accessed at [localhost:3000/flipper/features](http://localhost:3000/flipper/features). To enable a flag, press "Add Feature", paste in the name of a feature from [this list](https://hcb.hackclub.com/api/flags), and then press "Fully Enable".

## Getting an OAuth token

There is two different ways you can accomplish the first step of getting an OAuth token, either using a webpage, or the terminal depending on your preference.

1. Go to [http://localhost:3000/api/v4/oauth/applications](http://localhost:3000/api/v4/oauth/applications). Press "New Application" and then set the name to anything of your choosing, the redirect URI to `http://localhost:3000/`, and scopes to `read write`. For the purposes of this guide, you should leave confidential checked (see more context [here](oauth.net/2/client-types)). Press "Submit" and then save the info on the new page that appears and press "Authorize."

2. Open the rails console by running `bin/rails c`. Then, run `app = Doorkeeper::Application.create(name: "tester", redirect_uri: "http://localhost:3000/", scopes: ["read", "write"], confidential: false)` inside the console and save the output (you will need this later). After this, open `http://localhost:3000/api/v4/oauth/authorize?client_id=<UID>&redirect_uri=http://localhost:3000/&response_type=code&scope=read write`.

Press the button to approve access on the page, then copy the code that appears in the address bar after being redirected. Now, send a POST request to `http://localhost:3000/api/v4/oauth/token` with a content type of `application/x-www-form-urlencoded` (you can use a tool like [Postman](https://www.postman.com/) to do this!). The request body fields are as follows:
```
grant_type=authorization_code
code=<CODE>
client_id=<UID>
client_secret=<SECRET>
redirect_uri=http://localhost:3000/
```
This request will return your OAuth access token. It can then be passed into future API requests in the Authorization header. Ex. `Authorization: Bearer <ACCESS TOKEN>`
