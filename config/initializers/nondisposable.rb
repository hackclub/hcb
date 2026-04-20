# frozen_string_literal: true

Nondisposable.configure do |config|
  # Customize the error message if needed
  config.error_message = "provider is unsupported. Please try with another email address."

  # Sourced from https://hcb.hackclub.com/blazer/queries/1116-user-group-domain-by-usage
  #
  # NOTE: aol.com, and msn.com are semi-common email providers, but
  # have very few legitimate users. I'm choosing to block them because the pros
  # of blocking fraudulent users outweigh the cons of blocking a small number of
  # new legitimate users.
  hcb_sourced_domains = %w[
    aboodbab.com
    pupacloud.net
    phoboslink.com
    supermegamail.org
    privateconnect.net
    grnail.net
    assguard.org
    mxbros.org
    mamabood.com
    gmx.com
    toukib.com
    rambler.ru
    autorambler.ru
    bk.ru
    inbox.ru
    lenta.ru
    list.ru
    mail.ru
    myrambler.ru
    ro.ru
    msn.com
    aol.com
    rambler.ua
  ].freeze

  # https://www.okta.com/blog/threat-intelligence/opportunistic-sms-pumping-attacks-target-customer-sign-up-pages/
  # We've noticed some of these domains within HCB.
  okta_sourced_domains = %w[
    2mails1box.com
    300bucks.net
    blueink.top
    desumail.com
    e-boss.xyz
    e-mail.lol
    echat.rest
    electroletter.space
    emailclub.net
    energymail.org
    gogomail.ink
    gopostal.top
    guesswho.click
    homingpigeon.org
    kakdela.net
    letters.monster
    lostspaceship.net
    message.rest
    myhyperspace.org
    mypost.lol
    postalbro.com
    protonbox.pro
    rocketpost.org
    sendme.digital
    shroudedhills.com
    specialmail.online
    ultramail.pro
    whyusoserious.org
    wirelicker.com
    writeme.live
    writemeplz.net
  ].freeze

  # Add custom domains you want to be considered as disposable
  config.additional_domains = hcb_sourced_domains + okta_sourced_domains + [
    # Project people who mistype gmail.com, but these were also found in SMS pumping fraud
    "gmail.con",
    "gmail.co",
    "gamil.com"
  ]

  # Exclude domains that are considered disposable but you want to allow anyways
  # config.excluded_domains = ["false-positive-domain.com"]
end
