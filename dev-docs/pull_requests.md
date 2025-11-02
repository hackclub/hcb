# Pull Request Guide

- Use the PR template
- Preferably, prefix your branch names with your name. e.g. `garyhtou/branch-name`
- Update your branch by merging `main` into your feature branch rather than rebasing. Rebasing will create new commits causing review comments to shift out of order.
- Run `bin/lint -c`
- When merging PRs into main, squash and rebase

## Per-merge Checklist

- [ ] Descriptive PR title _(Does the title explain the changes in a concise manner?)_
- [ ] Easily digestible commits _(Are the commits small and easy to understand?)_ [video](https://gist.github.com/garyhtou/97534180b0753aa607c35b6fdda9d2e0)
- [ ] CI passes _(Do the GitHub checks pass?)_
- [ ] Tested by submitter before requesting review _(Does the test plan pass in development or staging?)_
- [ ] Tested by reviewer before merging <!-- leave this unchecked until right before merging -->
- [ ] After merging: Close related issues
- [ ] After merging: Notify the requestor of the issue. Post in [`#hcb-team`](https://hackclub.slack.com/archives/C026RKHLPNJ) if the feature impacts HCB's operations team
- [ ] After merging: Write and approve [`#ship`](https://hackclub.slack.com/archives/C0M8PUPU6) message
