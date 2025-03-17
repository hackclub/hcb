<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://cloud-djxhgxve6-hack-club-bot.vercel.app/0hcb-icon-icon-dark_1_.png">
    <img src="https://cloud-5yru8jas0-hack-club-bot.vercel.app/0logo-512.png" width="126" alt="HCB logo">
  </picture>
  <h1>HCB by Hack Club</h1>
</div>
<br>

> [!CAUTION]
> If you previously cloned this repository, please:
> 1. Delete your existing clone of this repository
> 2. Reclone it
>
> We recently performed a re-write of the git history in preparation for open
> sourcing HCB. Your old clone will cause conflicts unless it is deleted and
> recloned. Thank you!

Welcome to the [HCB](https://hackclub.com/fiscal-sponsorship/) codebase. We are so excited to have you. With your help, we can make HCB the best platform to run a nonprofit.

## What is HCB?

HCB is a powerful, safe, and easy-to-use fiscal sponsorship platform for hackathons, Hack Clubs, robotic teams and more. We use it to run our [fiscal sponsorship program](https://hackclub.com/fiscal-sponsorship/), we provide high schoolers with a 501(c)(3) status-backed restricted fund for their organization. Behind the scenes, HCB is a Ruby on Rails application (learn more by reading [our documentation](https://github.com/hackclub/hcb/blob/main/dev-docs/)).

<img width="1377" alt="Screenshot of Hack Club HQ's finances on HCB" src="https://github.com/hackclub/hcb/assets/39828164/b19a83b2-ba81-46b0-9f6f-2772f4249071">

## Table of Contents

- [What is HCB?](#what-is-hcb)
- [Table of Contents](#table-of-contents)
- [Contributing](#contributing)
- [Quick Start](#quick-start)
  - [Github Codespaces](#github-codespaces)
  - [Docker](#docker)
- [Deployment](#deployment)
- [Docs](https://github.com/hackclub/hcb/blob/main/dev-docs/)

## Contributing

We are so excited for you to join the codebase! We have a [guide to getting started](#quick-start) below and additional documentation in the [`dev-docs` folder](https://github.com/hackclub/hcb/blob/main/dev-docs/).

All contributors are expected to follow the Hack Club [Code of Conduct](https://hackclub.com/conduct) and Hack Club's [contributing guidelines](https://github.com/hackclub/hackclub/blob/main/CONTRIBUTING.md).

Join the [#hcb-engr-help](https://hackclub.slack.com/archives/C068U0JMV19) channel on the [Hack Club Slack](https://hackclub.com/slack) for support.

### I found a security vulnerability! What should I do?

Please email [hcb-security@hackclub.com](mailto:hcb-security@hackclub.com) to report the vulnerability. We currently don't have a bug bounty program but, as a token of appreciation, we'd love to mail you a t-shirt and give you a shoutout on our GitHub.

## Quick Start

### GitHub Codespaces

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new?hide_repo_select=true&ref=main&repo=135250235&skip_quickstart=true&machine=premiumLinux&devcontainer_path=.devcontainer%2Fdevcontainer.json&geo=UsWest)

[GitHub Codespaces](https://docs.github.com/en/codespaces) allows you to run a development environment without installing anything on your computer, allows for multiple instances, creates an overall streamlined and reproducible environment, and enables anyone with browser or VS Code access to contribute.

To get started, [whip up a codespace](https://docs.github.com/en/codespaces/getting-started/quickstart), open the command palette(<kbd>CTRL</kbd>+<kbd>SHIFT</kbd>+<kbd>P</kbd>), and search `Codespaces: Open in VS Code Desktop`. HCB does not work on the web version of Codespaces. Run `bin/dev`. If you can't open the link that is printed in the terminal, ensure the `3000` port is public under the `PORTS` tab in your terminal.

After creating your codespace, run `bundle install` and `bin/rails db:migrate`. This will finish preparing HCB for development.

### Docker

If you are running macOS or Ubuntu, you can clone the repository and run the [docker_dev_setup.sh](./docker_dev_setup.sh) script to automatically set up a development environment with Docker. Append `--with-solargraph` to the command to also setup [Solargraph](https://solargraph.org), a language server for Ruby. You may also need to install the [Solargraph extension](https://github.com/castwide/solargraph#using-solargraph) for your editor. This script should also work for Windows; although it's recommended that Window users run it (docker) within [WSL](https://learn.microsoft.com/en-us/windows/wsl/install)

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

If you have more questions about development check out our [docs](https://github.com/hackclub/hcb/blob/main/dev-docs/development.md)

### Credentials

We used [Doppler](https://www.doppler.com/) to manage our credentials; if you have access to Doppler, you can set a `DOPPLER_TOKEN` in your `.env` file. Otherwise, you can provide credentials via a `.env.development` file [(view example)](.env.development.example).

### Development Account

Login using the email admin@bank.engineering. Use Letter Opener (`/letter_opener`) to access the development email outbox and retrieve the login code.

### Staging Access

Login using the email staging@bank.engineering. Visit `#hcb-staging` on the [Hack Club Slack](https://hackclub.com/slack) for the code.

### Production Access

Please see this part of the [docs](https://github.com/hackclub/hcb/blob/main/dev-docs/development.md#production-access) for more information on production access.

## Deployment

All pushes to the `main` branch are automatically deployed by Heroku. We also
have staging deploys per PR/branch using Heroku pipelines.

---

<div align="center">
  <img src="./hcb_laser.gif" alt="Laser engraving of the HCB logo" width="500">
  <br>
  <p><strong>Happy hacking. ❤️</strong></p>
</div>

🔼 [Back to Top](#readme)
