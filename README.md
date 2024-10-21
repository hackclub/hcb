<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://cloud-djxhgxve6-hack-club-bot.vercel.app/0hcb-icon-icon-dark_1_.png">
    <img src="https://cloud-5yru8jas0-hack-club-bot.vercel.app/0logo-512.png" width="126" alt="HCB logo">
  </picture>
  <h1>HCB by Hack Club</h1>
</div>
<br>

Welcome to the [HCB](https://hackclub.com/fiscal-sponsorship/) codebase. We are so excited to have you. With your help, we can make HCB the best platform to run a nonprofit.

## What is HCB?

HCB is a powerful, safe, and easy-to-use fiscal sponsorship platform for hackathons, Hack Clubs, robotic teams and more. We use it to run our [fiscal sponsorship program](https://hackclub.com/fiscal-sponsorship/), we provide high schoolers with a 501(c)(3) status-backed restricted fund for their organization. Behind the scenes, HCB is a Ruby on Rails application (learn more on the [wiki](https://github.com/hackclub/hcb/wiki)).

<img width="1377" alt="Screenshot 2024-06-03 at 1 34 42 PM" src="https://github.com/hackclub/hcb/assets/39828164/b19a83b2-ba81-46b0-9f6f-2772f4249071">

## Table of Contents

- [What is HCB?](#what-is-hcb)
- [Table of Contents](#table-of-contents)
- [Contributing](#contributing)
- [Quick Start](#quick-start)
  - [Github Codespaces](#github-codespaces)
  - [Docker](#docker)
- [Deployment](#deployment)
- [Wiki](https://github.com/hackclub/hcb/wiki)

## Contributing

We are so excited for you to join the codebase! We have a [guide to getting started](#quick-start) below and additional documentation on the [wiki](https://github.com/hackclub/hcb/wiki).

All contributors are expected to follow the Hack Club [Code of Conduct](https://hackclub.com/conduct) and Hack Club's [contributing guidelines](https://github.com/hackclub/hackclub/blob/main/CONTRIBUTING.md).

Join the `#hcb-engr-help` channel on the [Hack Club Slack](https://hackclub.com/slack) for support.

### I found a security vulnerability! What should I do?

Please email [hcb-security@hackclub.com](mailto:hcb-security@hackclub.com) to report the vulnerability. We currently don't have a bug bounty program but, as a token of appreciation, we'd love to mail you a t-shirt and give you a shoutout on our GitHub.

## Quick Start

### GitHub Codespaces

[GitHub Codespaces](https://docs.github.com/en/codespaces) allows you to run a development environment without installing anything on your computer, allows for multiple instances, creates an overall streamlined and reproducible environment, and enables anyone with browser or VS Code access to contribute.

To get started, [whip up a codespace](https://docs.github.com/en/codespaces/getting-started/quickstart) and follow the steps in the [Automated Setup with Docker](#automated-setup-with-docker) section.

See the [Codespaces](./Codespaces.md) page for more information on developing in a GitHub Codespaces environment.

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

If you have more questions about development check out our [wiki](https://github.com/hackclub/hcb/wiki)

### Production Access

Please see this part of the [wiki](https://github.com/hackclub/hcb/wiki/Development/#production-access) for more information on Production Access

## Deployment

All pushes to the `main` branch are automatically deployed by Heroku.

---

<div align="center">
  <img src="./hcb_laser.gif" alt="Laser engraving of the HCB logo" width="500">
  <br>
  <p><strong>Happy hacking. ❤️</strong></p>
</div>

🔼 [Back to Top](#readme)
