<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://cloud-djxhgxve6-hack-club-bot.vercel.app/0hcb-icon-icon-dark_1_.png">
    <img src="https://cloud-5yru8jas0-hack-club-bot.vercel.app/0logo-512.png" width="126" alt="HCB logo">
  </picture>
  <h1>HCB by Hack Club</h1>
</div>
<br>

> [!TIP]
> 👋 Welcome Hack Clubbers! We're planning on open sourcing HCB in the near
> future, however, you cool lad have got 🎟️ early access to the HCB codebase!
>
> As you explore the codebase, I ask three things of you:
> - 📖 **Help us improve our docs.**
>
>   Ran into an issue setting up HCB locally or found a typo? Submit a PR!
>
> - 🔒 **Find and report security vulnerabilities.**
>
>   Discover a notable issue and we’ll ship you a cool HCB t-shirt as a thank
>   you!
>
> - 👥 **Keep it within the Hack Club community.**
>
>   Remember, you’ve got early access!
>
> If you have any questions, check out
> [#hcb-engr-help](https://hackclub.slack.com/archives/C068U0JMV19)
>
> ~ [@garyhtou](https://garytou.com)

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

HCB is a powerful, safe, and easy-to-use fiscal sponsorship platform for hackathons, Hack Clubs, robotic teams and more. We use it to run our [fiscal sponsorship program](https://hackclub.com/fiscal-sponsorship/), we provide high schoolers with a 501(c)(3) status-backed restricted fund for their organization. Behind the scenes, HCB is a Ruby on Rails application (learn more by reading [our documentation](/dev-docs)).

<img width="1377" alt="Screenshot of Hack Club HQ's finances on HCB" src="https://github.com/hackclub/hcb/assets/39828164/b19a83b2-ba81-46b0-9f6f-2772f4249071">

## Table of Contents

- [What is HCB?](#what-is-hcb)
- [Table of Contents](#table-of-contents)
- [Contributing](#contributing)
- [Quick Start](#quick-start)
  - [Credentials](#credentials)
  - [Development Account](#development-account)
  - [Staging Access](#staging-access)
  - [Production Access](#production-access)
- [Deployment](#deployment)
- [Docs](https://github.com/hackclub/hcb/blob/main/dev-docs/)

## Contributing

We are so excited for you to join the codebase! We have a getting started documentation in the [`dev-docs` folder](/dev-docs/development.md).

All contributors are expected to follow the Hack Club [Code of Conduct](https://hackclub.com/conduct) and Hack Club's [contributing guidelines](https://github.com/hackclub/hackclub/blob/main/CONTRIBUTING.md).

Join the [#hcb-engr-help](https://hackclub.slack.com/archives/C068U0JMV19) channel on the [Hack Club Slack](https://hackclub.com/slack) for support.

### I found a security vulnerability! What should I do?

Please email [hcb-security@hackclub.com](mailto:hcb-security@hackclub.com) to report the vulnerability. We currently don't have a bug bounty program but, as a token of appreciation, we'd love to mail you a t-shirt and give you a shoutout on our GitHub.

## Quick Start

To run HCB in a development enviroment, follow the setup instructions in our [documentation](/dev-docs/development.md). We support development through Codespaces, Docker, and a native setup.

### Credentials

We used [Doppler](https://www.doppler.com/) to manage our credentials; if you have access to Doppler, you can set a `DOPPLER_TOKEN` in your `.env` file. Otherwise, you can provide credentials via a `.env.development` file [(view example)](.env.development.example).

### Development Account

Login using the email admin@bank.engineering. Use Letter Opener (`/letter_opener`) to access the development email outbox and retrieve the login code.

### Staging Access

Login using the email staging@bank.engineering. Visit `#hcb-staging` on the [Hack Club Slack](https://hackclub.com/slack) for the code.

### Production Access

Please see this part of the [docs](/dev-docs/development.md#production-access) for more information on production access.

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
