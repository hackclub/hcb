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
end
