# frozen_string_literal: true

module MarketingHelper
  # Recipient organizations featured in the "Organizations on HCB" portfolio explorer on the
  # /for/funders page, in rail order. Each renders a rail item + a detail panel:
  # - :logo  — square brand mark shown in the rail (falls back to the :icon glyph if absent)
  # - :media — the panel's heading banner: :photo (a cropped published photo) or :logo (a brand
  #            mark/wordmark on a clean plate, for orgs without a usable wide photo)
  # - :focus — the photo's object-position, so faces aren't cropped
  # - :stat/:stat_label, :facts, :quote (+author), and :funded_by are all optional, so light and
  #   deep entries share the same flexible stage.
  #
  # `show_public_grids` gates the still-rolling-out Public Grids entry.
  def funder_recipients(show_public_grids:)
    ff_logo = "https://cdn.hackclub.com/019edcbb-71d3-755b-bf22-b4e958e3b0e9/founders_fund_logo__2015_.svg"
    ford_logo = "https://cdn.hackclub.com/019ed938-00a8-714d-bd51-3a7145ef976e/image.png"
    omidyar_logo = "https://cdn.hackclub.com/019ed938-0314-7502-9dca-4a7f342c53d7/image.png"
    sloan_logo = "https://cdn.hackclub.com/019edcbb-46d2-74bd-93d3-63bf843af555/image.png"
    ghostty_mark = "https://cdn.hackclub.com/019e8700-8100-7a6a-86eb-9f0e73b3320a/ghostty.svg"

    [
      {
        # `logo` (square icon for the rail) and `brand` (the cover of Reboot's print magazine
        # Kernel) are intentionally two different Reboot assets; orgs whose mark works at both
        # sizes (Ghostty) reuse one.
        key: "reboot", name: "Reboot", icon: "community",
        logo: "https://cdn.hackclub.com/019edef8-77a1-7c6c-aff6-d9dc8a1b9b67/apple-touch-icon-1024x1024.png",
        sub: "Publication & community on tech and society",
        url: "https://joinreboot.org",
        media: :photo, brand: "https://cdn.hackclub.com/019ef0bf-02df-73d4-86db-7d841f4466a7/image.png",
        brand_alt: "Cover of Reboot’s print magazine Kernel, an illustration of people boarding a train by a mountainside", focus: "center 70%",
        what: "A nonprofit publication and community on technology and society.",
        stat: "$400K+", stat_label: "raised on HCB",
        facts: [
          "A weekly newsletter to 8,000+ readers, plus its annual print magazine <em>Kernel</em>",
          "Founded in 2020 and run by volunteers, with no back office to staff",
        ],
        quote: "HCB’s platform has made it possible to scale Reboot’s team and operations in a way that would be otherwise impossible. The platform is extremely transparent and easy to use; and the team is incredibly kind and responsive.",
        author: "Jasmine Sun", author_role: "Co-founder of Reboot",
        author_avatar: "https://cdn.hackclub.com/019ed937-f871-772f-9b5f-1d54f33ae264/image.png",
        funded_by: [
          { logo: ford_logo, alt: "Ford Foundation" },
          { logo: omidyar_logo, alt: "Omidyar Network", class: "mk-portfolio__funder--omidyar" },
        ],
      },
      {
        key: "public_grids", name: "Public Grids", icon: "grid", gated: true,
        logo: "https://cdn.hackclub.com/019edf50-d85d-7f64-bff6-5199020944c5/672d11874901ca71dff9b9c2_PG-wordmark-color-giant.svg",
        sub: "National nonprofit expanding public power",
        url: "https://www.publicgrids.org",
        media: :photo, brand: "https://cdn.hackclub.com/019ee1cf-47e9-7370-8c8e-65cc2fa911cc/67210a406c5dda52abee0cb0_rachel-martin-7b2kx2rdnqM-unsplash-Resized.jpg",
        brand_alt: "People on the Griffith Observatory lawn at golden hour, with the Hollywood Hills behind", focus: "center 55%",
        what: "A national nonprofit working to expand public power: community-owned, democratically run electric utilities.",
        facts: [
          "Pairs grassroots organizing with expert utility modeling and policy analysis",
          "Champions public power, which already serves 54M+ Americans",
        ],
        quote: "No one comes close to the quality of Hack Club’s services at a price a startup like ours can afford. The in-house, flexible, tech-first platform lets us spend our team’s finite hours on our work, not on paperwork. But most of all, the team is incomparable in their integrity and transparency, which is why we keep choosing to grow with Hack Club as we scale.",
        author: "Isaac Sevier", author_role: "Founder & Executive Director of Public Grids",
        author_avatar: "https://cdn.hackclub.com/019edd08-6185-7556-a382-67f43d652c04/image.png",
      },
      {
        key: "curioss", name: "CURIOSS", icon: "community",
        logo: "https://cdn.hackclub.com/019ef115-f769-7ff8-bc2d-fcd1326becb5/color_logo_vert1.svg",
        sub: "Open source across universities & research",
        url: "https://curioss.org",
        media: :logo, brand: "https://cdn.hackclub.com/019ef115-fd15-7200-b180-76ad934859fe/color_horizontal_logotype1.svg",
        what: "A global community strengthening the open-source program offices that universities and research institutions rely on.",
        stat: "$750K+", stat_label: "in grants on HCB",
        facts: [
          "Founded in 2023 to connect open-source program offices across universities and research institutions worldwide",
          "Publishes shared standards for the field, including a widely used definition of an academic open-source office",
        ],
        quote: "HCB has been an excellent fiscal sponsor that we now routinely suggest to others. Their platform, and especially their amazingly, weirdly speedy team, has made our work a breeze. Cannot recommend enough.",
        author: "Richard Littauer", author_role: "Co-organizer of CURIOSS",
        author_avatar: "https://cdn.hackclub.com/019ef598-93fc-7e85-b848-394893f46186/richard-littauer.jpg",
        funded_by: [
          { logo: sloan_logo, alt: "Alfred P. Sloan Foundation" },
        ],
      },
      {
        key: "ghostty", name: "Ghostty", icon: "terminal", logo: ghostty_mark,
        sub: "Fast, open-source terminal emulator",
        url: "https://ghostty.org",
        # :terminal renders a CSS terminal-art banner (no published wide photo exists for a
        # terminal emulator); the rail still shows the ghost mark via `logo`.
        media: :terminal,
        what: "A fast, open-source terminal by HashiCorp co-founder Mitchell Hashimoto, sustained by tax-deductible community donations.",
        stat: "56K+", stat_label: "stars on GitHub",
        facts: [
          "Reached its 1.0 release in December 2024",
          "Open-source under the MIT license, built by a global community",
        ],
      },
      {
        key: "miami", name: "Miami Hack Week", icon: "code",
        logo: "https://cdn.hackclub.com/019edef8-828e-742a-aa66-993f07a1db66/favicon.svg",
        sub: "Miami's largest hackathon, 2021–2024",
        url: "https://miamihackweek.com",
        media: :photo, brand: "https://cdn.hackclub.com/019e8700-6497-7abf-984c-8536bf542151/image.png",
        brand_alt: "Founders and engineers at Miami Hack Week",
        what: "A week of building across themed hacker houses in Miami, run 2021–2024.",
        stat: "4,300+", stat_label: "builders & founders",
        facts: [
          "58+ themed hacker houses across four years",
          "$250K+ awarded in prizes",
        ],
        funded_by: [{ logo: ff_logo, alt: "Founders Fund" }],
      },
      {
        key: "malan", name: "Mutual Aid LA Network", icon: "people-2",
        logo: "https://cdn.hackclub.com/019edef8-85e1-7369-8176-d555700df66f/cropped-malan_logo_solidyellow_220626.png",
        sub: "LA mutual-aid hub for the 2025 wildfires",
        url: "https://mutualaidla.org",
        media: :photo, brand: "https://cdn.hackclub.com/019e870d-d4b0-7ebc-b8a4-928b663bd6c0/image.png",
        brand_alt: "Mutual Aid LA Network volunteers with donated supplies", focus: "center 20%",
        what: "An LA mutual-aid hub that channels donations and resources to grassroots community groups.",
        stat: "$1.4M+", stat_label: "raised on HCB for fire relief",
        facts: [
          "Mobilized within days of the January 2025 LA wildfires",
          "Redistributed to nearly 50 grassroots groups on the ground",
          "A fire-resources guide drew 100,000 views in a day",
        ],
      },
    ].reject { |org| org[:gated] && !show_public_grids }
  end

  # Rows for the "How it compares" table (HCB vs. private foundation vs. donor-advised fund) on
  # the /for/funders page. Each row renders a summary line plus a detail row that ships EXPANDED
  # in the HTML and is collapsed by the funders-compare Stimulus controller, so the evidence and
  # IRS sources are visible to AI crawlers and no-JS visitors. Per-row keys:
  # - :label — the comparison dimension (also the expand toggle's label)
  # - :hcb / :pf / :daf — the short value for each vehicle (:hcb_sub is an optional lighter clause)
  # - :detail — a per-vehicle hash { :hcb, :pf, :daf } of short explanations. On mobile only HCB and
  #   the chosen alternative show; desktop shows all three.
  # - :sources — optional list of { :text, :url, :for } cites (`for` tags the vehicle a source backs).
  #   They render together below the explanations.
  # Stats are verified against the cited IRS pages.
  def funder_comparison_rows
    irs = {
      life_cycle: "https://www.irs.gov/charities-non-profits/private-foundations/life-cycle-of-a-private-foundation-applying-to-the-irs",
      application: "https://www.irs.gov/charities-non-profits/charitable-organizations/wheres-my-application-for-tax-exempt-status",
      daf: "https://www.irs.gov/charities-non-profits/charitable-organizations/donor-advised-funds",
      payout: "https://www.irs.gov/charities-non-profits/private-foundations/taxes-on-failure-to-distribute-income-private-foundations",
      excise: "https://www.irs.gov/charities-non-profits/private-foundations/tax-on-net-investment-income",
      form990pf: "https://www.irs.gov/forms-pubs/about-form-990-pf",
      pub526: "https://www.irs.gov/publications/p526",
      deductions: "https://www.irs.gov/charities-non-profits/charitable-organizations/charitable-contribution-deductions"
    }

    [
      {
        label: "Setup cost", hcb: "$0", pf: "Legal & accounting + $600 IRS fee", daf: "Low",
        pf_status: "no", daf_status: "yes",
        detail: {
          hcb: "No entity to form and no setup cost. Your project runs on an established 501(c)(3), with the legal and compliance groundwork already in place.",
          pf: "Incorporate an entity and file IRS Form 1023 (a $600 user fee), plus legal and accounting work.",
          daf: "Inexpensive to open."
        },
        sources: [{ text: "IRS · Life cycle of a private foundation", url: irs[:life_cycle], for: "pf" }]
      },
      {
        label: "Time to first grant", hcb: "Days", pf: "Months", daf: "Days",
        pf_status: "no", daf_status: "yes",
        detail: {
          hcb: "Move within days of deciding. You build on an established 501(c)(3), so there's no new entity to form and no IRS waiting period.",
          pf: "Must file the full Form 1023 (the faster 1023-EZ isn't available to private foundations) and typically waits months for a determination letter before funders and banks treat its grants as settled.",
          daf: "Fast, like HCB. You can grant within days."
        },
        sources: [{ text: "IRS · Where's my application", url: irs[:application], for: "pf" }]
      },
      {
        label: "Practical minimum to be worth it", hcb: "None", pf: "~$250k to $1M+ commonly cited", daf: "Low",
        pf_status: "no", daf_status: "yes",
        detail: {
          hcb: "No minimum at all. Fund $500 or $5M.",
          pf: "Fixed setup and annual costs only pencil out at scale, commonly cited at roughly $250k to $1M+ in assets.",
          daf: "Little or no minimum, though its fees stack up as your balance grows."
        },
        sources: [{ text: "Foundation startup guidance", url: "https://www.cpakpa.com/learn-about-foundations/how-much-money-do-you-need-to-start-a-foundation", for: "pf" }]
      },
      {
        label: "Fund projects that aren't 501(c)(3)s", hcb: "Yes", pf: "Limited (expenditure responsibility)", daf: "No (existing charities only)",
        pf_status: "partial", daf_status: "partial",
        detail: {
          hcb: "Fund a charitable project now, even a brand-new one run by a single person, and it never has to incorporate. Because your gift funds charitable work and HCB makes sure it's used for that purpose, it stays fully tax-deductible.",
          pf: "Can support a non-charity, but only through expenditure responsibility, an added compliance step.",
          daf: "Most sponsors grant only to existing 501(c)(3) public charities. A sponsor can fund others through expenditure responsibility, but few do."
        },
        sources: [{ text: "IRS · Donor-advised funds", url: irs[:daf], for: "daf" }]
      },
      {
        label: "Back office (bank, cards, bookkeeping)", hcb: "Handled for funder & project", pf: "Build & staff your own", daf: "Recipient runs their own",
        pf_status: "no", daf_status: "partial",
        detail: {
          hcb: "HCB is the back office on both sides. The project gets a real bank account, debit cards, and bookkeeping; you get clean reporting, with compliance handled for you.",
          pf: "Can operate directly, but you build and staff that back office yourself.",
          daf: "The sponsor handles your account, but it grants to a charity that must already have its own bank account, accounting, and compliance."
        }
      },
      {
        label: "Donor control over grants", hcb: "You direct grants", hcb_sub: "compliance handled", pf: "Full", daf: "Advisory only",
        pf_status: "yes", daf_status: "partial",
        detail: {
          hcb: "You direct where grants go, and HCB keeps every grant compliant. Like any 501(c)(3) sponsor, HCB has final legal sign-off, which is what makes your gift deductible, but in practice you decide what to fund.",
          pf: "Full control, but you run the entity and its compliance.",
          daf: "You recommend grants; the sponsor holds legal control and approves them."
        },
        sources: [{ text: "IRS · Donor-advised funds", url: irs[:daf], for: "daf" }]
      },
      {
        label: "Mandatory annual payout & excise tax", hcb: "None", pf: "~5% payout + 1.39% excise", daf: "None",
        pf_status: "no", daf_status: "yes",
        detail: {
          hcb: "No mandatory payout and no excise tax.",
          pf: "Must pay out about 5% of investment assets each year or owe an initial 30% excise tax on the shortfall (rising to 100% if uncorrected), plus a 1.39% excise tax on net investment income.",
          daf: "No mandatory payout or excise tax."
        },
        sources: [{ text: "IRS · §4942 (payout)", url: irs[:payout], for: "pf" }, { text: "IRS · §4940 (excise)", url: irs[:excise], for: "pf" }]
      },
      {
        label: "Real-time transparency", hcb: "Real-time", hcb_sub: "every dollar as it moves", pf: "Annual (Form 990-PF)", daf: "Limited (periodic statements)",
        pf_status: "no", daf_status: "partial",
        detail: {
          hcb: "A real-time dashboard down to every transaction. See exactly where each dollar goes, break spending out by project and category, and turn it into the impact reports your board and stakeholders expect.",
          pf: "Reports publicly once a year on Form 990-PF.",
          daf: "Shows your contributions and grants out, but not live, transaction-level visibility into how the money is used."
        },
        sources: [{ text: "IRS · About Form 990-PF", url: irs[:form990pf], for: "pf" }]
      },
      {
        label: "Ongoing admin & cost", hcb: "We handle it", hcb_sub: "one simple fee", pf: "High (990-PF, staff/advisors)", daf: "Layered fees (admin + investment + advisor)",
        pf_status: "no", daf_status: "partial",
        detail: {
          hcb: "HCB handles bookkeeping, compliance, and reporting for you, for one simple fee, with no stacked or recurring charges.",
          pf: "File Form 990-PF annually and often need staff or advisors.",
          daf: "Low-effort to maintain, but costs stack up: an administrative (sponsor) fee, the underlying investment fees, and often a separate advisor fee, each charged on your balance, year after year."
        },
        sources: [{ text: "Fidelity Charitable · what a DAF costs", url: "https://www.fidelitycharitable.org/giving-account/what-it-costs.html", for: "daf" }]
      },
      {
        label: "Deduction limit, cash gifts", hcb: "Up to 60% of AGI", hcb_sub: "plus a 2026 break the others don't get", pf: "30% of AGI", daf: "Up to 60% of AGI",
        pf_status: "no", daf_status: "yes",
        detail: {
          hcb: "As a public charity, cash gifts are generally deductible up to 60% of AGI, and you can deduct appreciated assets such as stock or crypto at fair market value. Starting in 2026, non-itemizers can also deduct up to $1,000 ($2,000 joint) in cash gifts to public charities, a break that doesn't apply to DAFs or private foundations.",
          pf: "Cash gifts deductible up to 30% of AGI. Appreciated assets are capped at 20%, and non-publicly-traded stock is valued at cost basis.",
          daf: "Like HCB, a public charity: cash gifts deductible up to 60% of AGI, and appreciated assets at fair market value."
        },
        sources: [{ text: "IRS · Publication 526", url: irs[:pub526], for: "hcb" }, { text: "Tax Foundation · 2026 charitable deduction changes", url: "https://taxfoundation.org/blog/charitable-deduction-big-beautiful-bill/", for: "hcb" }]
      },
      {
        label: "Tax-deductible · 501(c)(3)", hcb: "Yes", pf: "Yes", daf: "Yes",
        pf_status: "yes", daf_status: "yes",
        detail: {
          hcb: "A tax-deductible gift backed by a real 501(c)(3). The limits differ (above), but the deduction is real.",
          pf: "Also a real 501(c)(3); your gift is deductible, at the lower limits above.",
          daf: "Also a real 501(c)(3); your gift is deductible at the same limits as HCB."
        },
        sources: [{ text: "IRS · Charitable contribution deductions", url: irs[:deductions], for: "hcb" }]
      }
    ]
  end

  # Q&A for the funder FAQ, grouped by topic. The full set renders on the dedicated
  # /for/funders/faq subpage; the `teaser: true` ones also surface in a short "Common questions"
  # block on the main funders page.
  def funder_faqs(stats: nil)
    [
      {
        topic: "Getting started and what you can fund",
        faqs: [
          {
            teaser: true,
            q: "How do I accept tax-deductible donations for a project that isn't a 501(c)(3)?",
            a: "Through fiscal sponsorship. Your charitable project runs on an established 501(c)(3), so donations are tax-deductible from day one, with no nonprofit of your own to form. The project keeps its own name and gets a real bank account, debit cards, and compliance, while HCB handles the paperwork for one simple fee.",
            related: ["fiscal-sponsorship"]
          },
          {
            q: "What kinds of projects can I fund through HCB?",
            a: "Charitable, mission-driven work of almost any size: open-source software, hackathons and student programs, research, mutual aid and disaster relief, robotics teams, new initiatives, and regranting programs. If it advances a charitable purpose, HCB can almost certainly support it, and we'll confirm fit on a call."
          },
          {
            q: "How fast can I actually start granting?",
            a: "In days, not quarters. Because the 501(c)(3) already exists, there's no new entity to form and no IRS waiting period. After an initial conversation, funders are typically up and granting within days."
          },
          {
            q: "Can I fund a brand-new project that's run by just one person?",
            a: "Yes. A project doesn't need a team, a track record, or its own legal entity. As long as it's doing charitable work, a single person can run it on HCB with a real bank account and cards, and your gift is tax-deductible."
          },
          {
            q: "Can I give money directly to an individual?",
            a: "Your gift funds charitable work, not a person's personal use. Unfortunately, IRS rules don't let a 501(c)(3) be a pass-through to a hand-picked individual, but it can still put money in people's hands for charitable purposes, like stipends, hardship relief, or paying someone to do the work. HCB keeps that line compliant so your gift stays deductible."
          },
          {
            q: "Does a project ever have to incorporate as its own nonprofit?",
            a: "No. Many organizations run on HCB for years and never incorporate. HCB is built to be long-term, reliable infrastructure, not a temporary step on the way to forming a 501(c)(3). Incorporate later if it makes sense for you, or never."
          },
          {
            q: "Can I move a project I already run onto HCB?",
            a: "Yes. Funders and organizations move existing initiatives onto HCB all the time. Onboarding is simple: sign a contract, invite your team, and transfer your existing funds. From there the project gets a real bank account, cards, and real-time reporting."
          },
          {
            q: "Can I fund charitable work outside the US?",
            a: "Yes. HCB supports charitable work in 40+ countries. International funding follows US law, including OFAC sanctions rules, and the practical limits of local banking, and our team helps you navigate it."
          }
        ]
      },
      {
        topic: "How HCB compares",
        faqs: [
          {
            teaser: true,
            q: "What are the alternatives to starting a private foundation?",
            a: "Donor-advised funds and HCB. A private foundation can cost thousands and take months to set up and only makes sense at scale. HCB lets you deploy grants in days for one simple fee, with real-time reporting, no setup cost, and the ability to fund projects that aren't yet 501(c)(3)s. HCB is a fiscal sponsor, but a rare kind that's built for funders, not just the projects it hosts.",
            related: ["fiscal-sponsorship"]
          },
          {
            teaser: true,
            q: "How is HCB different from a donor-advised fund?",
            a: "A donor-advised fund grants money to existing 501(c)(3) public charities and holds the rest. HCB can fund and operate brand-new charitable projects, giving each a bank account, cards, and compliance, and showing you every dollar in real time. A DAF holds money and grants it to existing charities; HCB holds and grants too, and runs the back office that makes the funded work happen.",
            related: ["is-hcb-a-daf", "fiscal-sponsorship"]
          },
          {
            q: "Donor-advised fund vs. private foundation vs. HCB: which is right for me?",
            a: "A private foundation gives maximum control but is costly and slow. A donor-advised fund is simple but can only grant to existing charities. HCB fits funders who want to move fast, fund projects rather than just established nonprofits, and see exactly where the money goes. Many funders use HCB alongside a DAF or foundation."
          },
          {
            id: "fiscal-sponsorship",
            q: "What is fiscal sponsorship?",
            a: "Fiscal sponsorship is when an established 501(c)(3) lets a charitable project operate under its tax-exempt status, so the project can accept tax-deductible donations and run real finances without forming its own nonprofit. HCB is a fiscal sponsor, but an unusual one: most fiscal sponsors serve only the projects they host, while HCB is also built for the funders backing them, with real-time visibility and the tools to deploy capital at scale."
          },
          {
            id: "is-hcb-a-daf",
            q: "Is HCB a donor-advised fund?",
            a: "No. HCB is fiscal sponsorship: your charitable project operates under an established 501(c)(3) with its own account and identity, not a donor-advised account that can only grant to other charities. That's why HCB can fund brand-new, not-yet-incorporated work that a DAF can't.",
            related: ["fiscal-sponsorship"]
          },
          {
            q: "Do donor-advised funds have a payout requirement?",
            a: "No. Donor-advised funds have no federal payout requirement, unlike private foundations, which must distribute about 5% of their assets each year. HCB has no payout requirement either, but it's built to put money to work, with a real-time record of every dollar.",
            sources: [{ text: "IRS · §4942 (payout)", url: "https://www.irs.gov/charities-non-profits/private-foundations/taxes-on-failure-to-distribute-income-private-foundations" }, { text: "IRS · Donor-advised funds", url: "https://www.irs.gov/charities-non-profits/charitable-organizations/donor-advised-funds" }]
          },
          {
            q: "Can I keep my existing DAF or foundation and use HCB alongside it?",
            a: "Yes. You don't have to choose. Many funders grant from their DAF or foundation into HCB to reach fast-moving projects and brand-new initiatives those vehicles can't fund directly, with real-time visibility into every dollar."
          }
        ]
      },
      {
        topic: "Control and involvement",
        faqs: [
          {
            teaser: true,
            q: "Who decides where the money goes, me or HCB?",
            a: "You direct where grants go. HCB's role is to keep every grant compliant and handle the money movement, paperwork, and reporting. As with any 501(c)(3), the charity retains final legal discretion, which is what makes your gift deductible, but in practice you choose what to fund."
          },
          {
            q: "Does my project keep its own identity and get credit for the work?",
            a: "Yes. Your project keeps its own name and brand, and the work and the funding are credited to it, not to HCB. HCB is the financial infrastructure behind the scenes, the account, cards, and compliance, not the public face. The funds sit under an established 501(c)(3), which is what makes gifts tax-deductible, but day to day your project operates as itself, and the impact is yours to claim and report."
          },
          {
            q: "Can I run a regranting program, funding many projects at once?",
            a: "Yes. Funders use HCB to regrant across dozens or hundreds of recipients without standing up a back office. You bring the thesis and the picks; HCB handles disbursement, compliance, and real-time reporting at scale."
          },
          {
            q: "How hands-on can I be with the projects I fund?",
            a: "As hands-on as you like. You choose the projects, initiatives, and impact you want to back. Want to be deeply involved? Great. Prefer to lean on our expertise to run it for you? We can take the wheel."
          },
          {
            q: "Can HCB decline a grant I want to make?",
            a: "Compliance comes first, and we're upfront about it. We work with you to make every grant compliant, and if IRS rules wouldn't allow one, we tell you before taking the money, not after. We won't accept funds we can't put to work, so nothing ever gets stuck."
          },
          {
            q: "Can I set milestones or track impact on my grants?",
            a: "Yes. HCB helps funders gather the impact metrics and reporting they need. Tell us what you want to measure and we'll help you track it."
          }
        ]
      },
      {
        topic: "Tax and deductibility",
        faqs: [
          {
            q: "Is my gift tax-deductible?",
            a: "Yes. You give to HCB by Hack Club, legally The Hack Foundation, a registered 501(c)(3) public charity, so your deduction is immediate."
          },
          {
            q: "Is my gift still deductible if I pick the specific project I want to support?",
            a: "Yes. Choosing a charitable project to support doesn't affect deductibility, because HCB retains discretion and control and ensures the money is used for charitable purposes. What isn't deductible is earmarking a gift for a specific individual's personal benefit, which HCB doesn't do."
          },
          {
            q: "Who is the 501(c)(3) behind HCB, and what's the EIN?",
            a: "HCB is operated by The Hack Foundation (Hack Club), a registered 501(c)(3) nonprofit, EIN 81-2908499. When you look us up, that's who you'll find."
          },
          {
            q: "What is Hack Club, and is hacking a bad thing?",
            a: "Hack Club is the 501(c)(3) nonprofit (legally The Hack Foundation) that runs HCB. Founded in 2014, it supports a global community of more than 100,000 young people building across 1,000+ clubs worldwide, and it created HCB as the financial platform to move money for that work. Here, 'hacking' means building things, not breaking them. It's the resourceful, creative problem-solving the word originally meant in tech. The organization behind the name is a real, independently audited 501(c)(3) that serious funders and nonprofits already trust."
          },
          {
            q: "What are the deduction limits, and how do they compare to a private foundation?",
            a: "Because HCB is a public charity, cash gifts are generally deductible up to 60% of AGI, versus 30% for a private foundation. Appreciated assets like stock or crypto are deductible at fair market value, up to 30% of AGI, versus 20% for a foundation. This isn't tax advice; confirm specifics with your advisor.",
            sources: [{ text: "IRS · Publication 526", url: "https://www.irs.gov/publications/p526" }]
          },
          {
            q: "How do the 2026 tax-law (OBBBA) changes affect my deduction?",
            a: "Starting in tax year 2026, federal rules add a 0.5%-of-AGI floor on itemized charitable deductions, cap their value at 35% for top-bracket donors, and let non-itemizers deduct up to $1,000 ($2,000 joint) in cash gifts to public charities, a break that doesn't apply to DAFs or private foundations. Talk to your tax advisor about your situation.",
            sources: [{ text: "IRS · Publication 526", url: "https://www.irs.gov/publications/p526" }, { text: "Tax Foundation · 2026 charitable deduction changes", url: "https://taxfoundation.org/blog/charitable-deduction-big-beautiful-bill/" }]
          },
          {
            q: "Will I get a receipt for my gift?",
            a: "Yes. You receive an acknowledgment and receipt for every tax-deductible gift, so you have what you need at tax time."
          }
        ]
      },
      {
        topic: "Money, assets, and fees",
        faqs: [
          {
            q: "Can I donate stock, crypto, or other appreciated assets?",
            a: "Yes. HCB accepts cash, stock, crypto, wire transfers, and grants from a donor-advised fund or foundation. Stock and crypto are liquidated to cash on receipt. Giving appreciated assets to a public charity like HCB can be especially efficient, since you generally deduct the full fair market value."
          },
          {
            q: "Where is my money held, and is it FDIC-insured?",
            a: "Your funds are held at HCB's banking partners, Column N.A. and The Business Bank, and are FDIC-insured through the IntraFi network. HCB runs on bank-grade infrastructure, not a patchwork of tools."
          },
          {
            q: "Do I have to grant the money right away, or can I hold it?",
            a: "There's no requirement to spend immediately; you can hold funds in HCB long-term. That said, HCB exists to put money to work and create impact, so most funders use it to deploy quickly rather than park funds."
          },
          {
            q: "What happens to unspent funds if a project winds down?",
            a: "You stay in control of the unspent balance. If a project you funded closes with money left over, you can re-grant it to another project or charitable organization. By IRS rules the funds stay dedicated to charitable purposes and never revert to you personally, but you decide where they go next."
          },
          {
            q: "How much does HCB cost?",
            a: "HCB's pricing is simple: one straightforward fee, with none of the stacked administrative, investment, and advisor fees that pile up in other vehicles. We'll walk you through the specifics on a call."
          },
          {
            q: "Can I get my money back if I change my mind?",
            a: "Unfortunately, IRS rules don't allow it: like any tax-deductible charitable gift, contributions are irrevocable once they're made. It's the same for donor-advised funds and private foundations, and it's the trade-off for the tax deduction you receive."
          }
        ]
      },
      {
        topic: "Trust, compliance, and risk",
        faqs: [
          {
            teaser: true,
            q: "Is it safe to move serious money through HCB?",
            a: "Yes. HCB is high-tech financial infrastructure, built by engineers from the ground up rather than a patchwork of off-the-shelf tools, with bank-level security through reputable partners like Column and Stripe. The platform itself is open source, so its code is public for anyone to inspect. Every dollar sits behind a real, registered 501(c)(3), The Hack Foundation (EIN 81-2908499), is independently audited every year, and is tracked in real time. Funders moving large sums work directly with our team."
          },
          {
            q: "Does HCB have an API? Can I integrate it with my own tools?",
            a: "Yes. HCB is API-first, so you can integrate it with your own systems, automate regranting, and pull real-time spend and transaction data programmatically, straight into your dashboards or impact reports. It's far ahead of the closed, legacy systems most foundations and donor-advised funds run on."
          },
          {
            q: "What compliance and due diligence does HCB run?",
            a: "HCB handles 501(c)(3) compliance on every project and grant, and runs fraud auditing across transactions and financials. Keeping the money compliant is HCB's job, not yours."
          },
          {
            q: "Is HCB audited?",
            a: "Yes. HCB is independently audited every year, on top of the ongoing 501(c)(3) compliance and fraud monitoring built into the platform."
          },
          {
            q: "Who's responsible if a funded project misuses money or fails?",
            a: "HCB takes that risk off you. As the 501(c)(3) of record, HCB runs compliance, oversight, and fraud monitoring on every project, so a funder isn't on the hook for a project's missteps."
          },
          {
            q: "How much money has HCB moved, and how many organizations run on it?",
            a: "More than #{stats&.dig(:moved)} has moved through HCB, across #{stats&.dig(:organizations)} organizations, from small projects on a $500 budget to operations running tens of millions annually. Every dollar sits behind a registered 501(c)(3) with real-time reporting."
          }
        ]
      },
      {
        topic: "Reporting and transparency",
        faqs: [
          {
            teaser: true,
            q: "What visibility do I get into how my money is spent?",
            a: "A real-time dashboard down to every transaction. You can see exactly where each dollar goes, break spending out by project and category, and turn it into the impact reports your board and stakeholders expect, instead of waiting for a year-end PDF."
          },
          {
            q: "Can I give privately or anonymously?",
            a: "Yes. Transparency is optional. You can give publicly, privately, or anonymously, and choose how much of a project's activity is visible."
          }
        ]
      }
    ]
  end

  # The funder-facing team, shared by the main page's "you'll hear from one of us" CTA and the FAQ
  # page's "didn't find your answer" card, so the roster stays in sync in both places.
  def funder_team
    [
      { name: "Melanie Smith", avatar: "https://cdn.hackclub.com/019e7570-8304-7de8-abfe-cbcaf12616b7/image.png" },
      { name: "Paul Spitler", avatar: "https://cdn.hackclub.com/019e7570-80b5-7eae-9d54-cf4bf1460953/image.png" },
      { name: "Gary Tou", avatar: "https://cdn.hackclub.com/019e7570-7d87-707e-bb85-4d39a3fc5114/image.png" }
    ]
  end
end
