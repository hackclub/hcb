/* eslint react/prop-types:0 */

import { Priority } from 'kbar'
import Icon from '@hackclub/icons'
import csrf from '../../common/csrf'
import React from 'react'
import SvgIcon, { preload } from '../icons/SvgIcon'

preload(
  '/icons/hashtag.svg',
  '/icons/cheque.svg',
  '/icons/perks.svg',
  '/icons/receipt.svg',
  '/icons/reimbursement.svg',
  '/icons/wise.svg',
  '/icons/column.svg'
)

const restrictedFilter = e => !e.demo_mode

export const generateEventActions = data => {
  return [
    ...data.map(event => ({
      id: event.slug,
      name: event.name,
      icon:
        event.logo && event.logo != 'none' ? (
          <img
            src={event.logo}
            height="16px"
            width="16px"
            style={{ borderRadius: '4px' }}
          />
        ) : (
          <Icon glyph="bank-account" size={16} />
        ),
      priority: !event.member ? Priority.LOW : Priority.HIGH,
      section: 'Organizations',
    })),
    ...data.map(event => ({
      id: `${event.slug}-home`,
      name: 'Home',
      perform: navigate(`/${event.slug}`),
      icon: <Icon glyph="home" size={16} />,
      parent: event.slug,
    })),
    ...data.filter(restrictedFilter).map(event => ({
      id: `${event.slug}-announcements`,
      name: 'Announcements',
      perform: navigate(`/${event.slug}/announcements`),
      icon: <Icon glyph="announcement" size={16} />,
      parent: event.slug,
    })),
    ...data.filter(restrictedFilter).map(event => ({
      id: `${event.slug}-transactions`,
      name: 'Transactions',
      perform: navigate(`/${event.slug}/transactions`),
      icon: <Icon glyph="bank-account" size={16} />,
      parent: event.slug,
      keywords: 'ledger payments',
    })),
    ...data.filter(restrictedFilter).map(event => ({
      id: `${event.slug}-account-number`,
      name: 'Account numbers',
      perform: navigate(`/${event.slug}/account-number`),
      icon: <SvgIcon src="/icons/hashtag.svg" size={16} />,
      parent: event.slug,
    })),
    ...data.filter(restrictedFilter).map(event => ({
      id: `${event.slug}-donations`,
      name: 'Donations',
      perform: navigate(`/${event.slug}/donations`),
      icon: <Icon glyph="support" size={16} />,
      parent: event.slug,
    })),
    ...data.filter(restrictedFilter).map(event => ({
      id: `${event.slug}-invoices`,
      name: 'Invoices',
      perform: navigate(`/${event.slug}/invoices`),
      icon: <Icon glyph="payment-docs" size={16} />,
      parent: event.slug,
    })),
    ...data.filter(restrictedFilter).map(event => ({
      id: `${event.slug}-check-deposit`,
      name: 'Check deposits',
      perform: navigate(`/${event.slug}/check-deposits`),
      icon: <SvgIcon src="/icons/cheque.svg" size={16} />,
      parent: event.slug,
    })),
    ...data.map(event => ({
      id: `${event.slug}-cards`,
      name: 'Cards',
      perform: navigate(`/${event.slug}/cards`),
      icon: <Icon glyph="card" size={16} />,
      parent: event.slug,
    })),
    ...data.filter(restrictedFilter).map(event => ({
      id: `${event.slug}-transfers`,
      name: 'Transfers',
      perform: navigate(`/${event.slug}/transfers`),
      icon: <Icon glyph="payment-transfer" size={16} />,
      parent: event.slug,
      keywords: 'ach check',
    })),
    ...data.filter(restrictedFilter).map(event => ({
      id: `${event.slug}-reimbursements`,
      name: 'Reimbursements',
      perform: navigate(`/${event.slug}/reimbursements`),
      icon: <SvgIcon src="/icons/reimbursement.svg" size={16} />,
      parent: event.slug,
    })),
    ...data.map(event => ({
      id: `${event.slug}-team`,
      name: 'Team',
      perform: navigate(`/${event.slug}/team`),
      icon: <Icon glyph="people-2" size={16} />,
      parent: event.slug,
    })),
    ...data
      .filter(e => e.features.card_grants)
      .map(event => ({
        id: `${event.slug}-card-grants`,
        name: 'Grants',
        perform: navigate(`/${event.slug}/card_grants`),
        icon: <Icon glyph="bag" size={16} />,
        parent: event.slug,
      })),
    ...data.filter(restrictedFilter).map(event => ({
      id: `${event.slug}-perks`,
      name: 'Perks',
      perform: navigate(`/${event.slug}/promotions`),
      icon: <SvgIcon src="/icons/perks.svg" size={16} />,
      parent: event.slug,
    })),
    ...data.filter(restrictedFilter).map(event => ({
      id: `${event.slug}-google-workspace`,
      name: 'Google Workspace',
      perform: navigate(`/${event.slug}/google_workspace`),
      icon: <Icon glyph="google" size={16} />,
      parent: event.slug,
    })),
    ...data.filter(restrictedFilter).map(event => ({
      id: `${event.slug}-documents`,
      name: 'Documents',
      perform: navigate(`/${event.slug}/documents`),
      icon: <Icon glyph="docs" size={16} />,
      parent: event.slug,
    })),
    ...data
      .filter(e => e.features.subevents)
      .map(event => ({
        id: `${event.slug}-subevents`,
        name: 'Sub-organizations',
        perform: navigate(`/${event.slug}/sub_organizations`),
        icon: <Icon glyph="channels" size={16} />,
        parent: event.slug,
      })),
    ...data.filter(restrictedFilter).map(event => ({
      id: `${event.slug}-settings`,
      name: 'Settings',
      perform: navigate(`/${event.slug}/settings`),
      icon: <Icon glyph="settings" size={16} />,
      parent: event.slug,
    })),
  ]
}

export const initalActions = [
  {
    id: 'search-main',
    name: 'Search HCB',
    keywords: 'search',
    icon: <Icon glyph="search" size={16} />,
    priority: Priority.HIGH,
  },
  {
    id: 'my-home',
    name: 'Home',
    keywords: 'index',
    perform: navigate('/'),
    icon: <Icon glyph="home" size={16} />,
    section: 'Pages',
    priority: Priority.HIGH,
  },
  {
    id: 'my-feed',
    name: 'Feed',
    keywords: 'index',
    perform: navigate('/my/feed'),
    icon: <Icon glyph="announcement" size={16} />,
    section: 'Pages',
    priority: Priority.HIGH,
  },
  {
    id: 'my-cards',
    name: 'Cards',
    keywords: 'cards',
    perform: navigate('/my/cards'),
    section: 'Pages',
    icon: <Icon glyph="card" size={16} />,
    priority: Priority.HIGH,
  },
  {
    id: 'my-receipts',
    name: 'Receipts',
    keywords: 'receipts inbox',
    perform: navigate('/my/inbox'),
    section: 'Pages',
    icon: <SvgIcon src="/icons/receipt.svg" size={16} />,
    priority: Priority.HIGH,
  },
  {
    id: 'my-reimbursements',
    name: 'Reimbursements',
    keywords: 'reimbursements report',
    perform: navigate('/my/reimbursements'),
    section: 'Pages',
    icon: <SvgIcon src="/icons/reimbursement.svg" size={16} />,
    priority: Priority.HIGH,
  },
  {
    id: 'my-settings',
    name: 'Settings',
    keywords: 'settings',
    section: 'Pages',
    icon: <Icon glyph="settings" size={16} />,
    priority: Priority.HIGH,
  },
  {
    id: 'my-settings-account',
    name: 'Account',
    keywords: 'account profile personal name birthday picture email sign',
    perform: navigate('/my/settings'),
    parent: 'my-settings',
    icon: <Icon glyph="profile" size={16} />,
    priority: Priority.HIGH,
  },
  {
    id: 'my-settings-notifications',
    name: 'Notifications',
    keywords: 'notifications alerts emails',
    perform: navigate('/my/settings/notifications'),
    parent: 'my-settings',
    icon: <Icon glyph="notification" size={16} />,
    priority: Priority.HIGH,
  },
  {
    id: 'my-settings-payouts',
    name: 'Payout settings',
    keywords: 'reimbursement payouts payment bank direct deposit',
    perform: navigate('/my/settings/payouts'),
    parent: 'my-settings',
    icon: <Icon glyph="payment-transfer" size={16} />,
    priority: Priority.HIGH,
  },
  {
    id: 'my-settings-security',
    name: 'Security',
    keywords: 'security password authentication 2fa two-factor',
    perform: navigate('/my/settings/security'),
    parent: 'my-settings',
    icon: <Icon glyph="private" size={16} />,
    priority: Priority.HIGH,
  },
  {
    id: 'my-settings-previews',
    name: 'Feature previews',
    keywords: 'feature previews beta experimental',
    perform: navigate('/my/settings/previews'),
    parent: 'my-settings',
    icon: <Icon glyph="rep" size={16} />,
    priority: Priority.HIGH,
  },
  {
    id: `theme-light`,
    name: `Set theme to light`,
    section: 'Actions',
    icon: <Icon glyph="sun" size={16} />,
    keywords: 'theme light', // eslint-disable-next-line no-undef
    perform: () => BK.setDark('light'),
  },
  {
    id: `theme-dark`,
    name: `Set theme to dark`,
    section: 'Actions',
    icon: <Icon glyph="moon" size={16} />,
    keywords: 'theme dark', // eslint-disable-next-line no-undef
    perform: () => BK.setDark('dark'),
  },
  {
    id: `theme-system`,
    name: `Set theme to system`,
    section: 'Actions',
    icon: <Icon glyph="lightbulb" size={16} />,
    keywords: 'theme system', // eslint-disable-next-line no-undef
    perform: () => BK.setDark('system'),
  },
  {
    id: 'signout',
    name: 'Sign out',
    keywords: 'sign out logout log out',
    perform: () =>
      fetch('/users/logout', {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrf(),
        },
      }).then(navigate('/')),
    section: 'Actions',
    icon: <Icon glyph="door-leave" size={16} />,
    priority: Priority.HIGH,
  },
]

export const adminActions = (adminUrls, isPretending) => {
  if (isPretending) {
    return [
      {
        id: 'admin-pretend',
        name: 'Stop pretending not to be an admin',
        keywords: 'pretend admin',
        perform: () =>
          fetch('/users/toggle_pretend_is_not_admin', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-CSRF-Token': csrf(),
            },
          }).then(navigate('/')),
        section: 'Actions',
        icon: <Icon glyph="bolt" size={16} />,
        priority: Priority.HIGH,
      },
    ]
  }
  return [
    {
      id: 'admin-pretend',
      name: 'Pretend to not be an admin',
      keywords: 'pretend admin',
      perform: () =>
        fetch('/users/toggle_pretend_is_not_admin', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': csrf(),
          },
        }).then(navigate('/')),
      section: 'Actions',
      icon: <Icon glyph="bolt" size={16} />,
      priority: Priority.HIGH,
    },
    // spending
    {
      id: 'admin-ach-transfers',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'ACH transfers',
      icon: <Icon glyph="payment-transfer" size={16} />,
      perform: navigate('/admin/ach'),
    },
    {
      id: 'admin-checks',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Checks',
      icon: <Icon glyph="payment-docs" size={16} />,
      perform: navigate('/admin/increase_checks'),
    },
    {
      id: 'admin-disbursements',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Disbursements',
      icon: <Icon glyph="payment-transfer" size={16} />,
      perform: navigate('/admin/disbursements'),
    },
    {
      id: 'admin-paypal',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'PayPal transfers',
      icon: <Icon glyph="paypal" size={16} />,
      perform: navigate('/admin/paypal_transfers'),
    },
    {
      id: 'admin-wires',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Wires',
      icon: <Icon glyph="web" size={16} />,
      perform: navigate('/admin/wires'),
    },
    {
      id: 'admin-wise-transfers',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Wise transfers',
      icon: <SvgIcon src="/icons/wise.svg" size={16} />,
      perform: navigate('/admin/wise_transfers'),
    },
    {
      id: 'admin-reimbursements',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Reimbursements',
      icon: <SvgIcon src="/icons/reimbursement.svg" size={16} />,
      perform: navigate('/admin/reimbursements'),
    },
    // ledger
    {
      id: 'admin-ledger',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Ledger',
      icon: <Icon glyph="list" size={16} />,
      perform: navigate('/admin/ledger'),
    },
    {
      id: 'admin-pending-ledger',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Pending ledger',
      icon: <Icon glyph="list" size={16} />,
      perform: navigate('/admin/pending_ledger'),
    },
    {
      id: 'admin-raw-transactions',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Raw transactions',
      icon: <Icon glyph="list" size={16} />,
      perform: navigate('/admin/raw_transactions'),
    },
    {
      id: 'admin-intrafi-transactions',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Intrafi transactions',
      icon: <Icon glyph="list" size={16} />,
      perform: navigate('/admin/raw_intrafi_transactions'),
    },
    {
      id: 'admin-hcb-codes',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'HCB codes',
      icon: <Icon glyph="list" size={16} />,
      perform: navigate('/admin/hcb_codes'),
    },
    {
      id: 'admin-unknown-merchants',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Unknown merchants',
      icon: <Icon glyph="search" size={16} />,
      perform: navigate('/admin/unknown_merchants'),
    },
    {
      id: 'admin-audits',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Audits',
      icon: <Icon glyph="flag" size={16} />,
      perform: navigate('/admin/ledger_audits'),
    },
    // incoming money
    {
      id: 'admin-donations',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Donations',
      icon: <Icon glyph="support" size={16} />,
      perform: navigate('/admin/donations'),
    },
    {
      id: 'admin-recurring-donations',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Recurring donations',
      icon: <Icon glyph="transactions" size={16} />,
      perform: navigate('/admin/recurring_donations'),
    },
    {
      id: 'admin-invoices',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Invoices',
      icon: <Icon glyph="docs-fill" size={16} />,
      perform: navigate('/admin/invoices'),
    },
    {
      id: 'admin-sponsors',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Sponsors',
      icon: <Icon glyph="purse" size={16} />,
      perform: navigate('/admin/sponsors'),
    },
    {
      id: 'admin-check-deposits',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Check deposits',
      icon: <SvgIcon src="/icons/cheque.svg" size={16} />,
      perform: navigate('/admin/check_deposits'),
    },
    // organizations
    {
      id: 'admin-applications-hcb',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Applications (HCB)',
      icon: <Icon glyph="post" size={16} />,
      perform: navigate('/admin/applications'),
    },
    {
      id: 'admin-organizations',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Organizations',
      icon: <Icon glyph="explore" size={16} />,
      perform: navigate('/admin/events'),
    },
    {
      id: 'admin-organization-balances',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Organization balances',
      icon: <Icon glyph="payment" size={16} />,
      perform: navigate('/admin/balances'),
    },
    {
      id: 'admin-opdrs',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'OPDRs',
      icon: <Icon glyph="member-remove" size={16} />,
      perform: navigate('/organizer_position_deletion_requests'),
    },
    {
      id: 'admin-gsuite',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Google Workspaces',
      icon: <Icon glyph="google" size={16} />,
      perform: navigate('/admin/google_workspaces'),
    },
    {
      id: 'admin-account-numbers',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Account numbers',
      icon: <SvgIcon src="/icons/hashtag.svg" size={16} />,
      perform: navigate('/admin/account_numbers'),
    },
    // payroll
    {
      id: 'admin-employees',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Employees',
      icon: <Icon glyph="person-badge" size={16} />,
      perform: navigate('/admin/employees'),
    },
    {
      id: 'admin-payments',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Payments',
      icon: <Icon glyph="payment-transfer" size={16} />,
      perform: navigate('/admin/employee_payments'),
    },
    {
      id: 'admin-w9s',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'W9s',
      icon: <Icon glyph="docs" size={16} />,
      perform: navigate('/admin/w9s'),
    },
    // misc
    {
      id: 'admin-blazer',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Blazer',
      icon: <Icon glyph="bolt" size={16} />,
      perform: navigate('/blazer'),
    },
    {
      id: 'admin-flipper',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Flipper',
      icon: <Icon glyph="flag-fill" size={16} />,
      perform: navigate('/flipper/features'),
    },
    {
      id: 'admin-common-documents',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Common documents',
      icon: <Icon glyph="docs" size={16} />,
      perform: navigate('/documents'),
    },
    {
      id: 'admin-bank-accounts',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Bank accounts',
      icon: <Icon glyph="bank" size={16} />,
      perform: navigate('/admin/bank_accounts'),
    },
    {
      id: 'admin-hcb-fees',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'HCB fees',
      icon: <Icon glyph="bank-circle" size={16} />,
      perform: navigate('/admin/bank_fees'),
    },
    {
      id: 'admin-fee-revenues',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Fee revenues',
      icon: <Icon glyph="bank-circle" size={16} />,
      perform: navigate('/admin/fee_revenues'),
    },
    {
      id: 'admin-column-statements',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Column statements',
      icon: <SvgIcon src="/icons/column.svg" size={16} />,
      perform: navigate('/admin/column_statements'),
    },
    {
      id: 'admin-users',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Users',
      icon: <Icon glyph="leaders" size={16} />,
      perform: navigate('/admin/users'),
    },
    {
      id: 'admin-cards',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Cards',
      icon: <Icon glyph="card" size={16} />,
      perform: navigate('/admin/stripe_cards'),
    },
    {
      id: 'admin-card-designs',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Card designs',
      icon: <Icon glyph="card" size={16} />,
      perform: navigate('/admin/stripe_card_personalization_designs'),
    },
    {
      id: 'admin-emails',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Emails',
      icon: <Icon glyph="email" size={16} />,
      perform: navigate('/admin/emails'),
    },
    {
      id: 'admin-referral-programs',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Referral programs',
      icon: <Icon glyph="share" size={16} />,
      perform: navigate('/admin/referral_programs'),
    },
    {
      id: 'admin-event-groups',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Event groups',
      icon: <Icon glyph="group" size={16} />,
      perform: navigate('/admin/event_groups'),
    },
    {
      id: 'admin-contracts',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Contracts',
      icon: <Icon glyph="docs" size={16} />,
      perform: navigate('/admin/contracts'),
    },
    {
      id: 'admin-active-teens-leaderboard',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Active teenagers leaderboard',
      icon: <Icon glyph="leader" size={16} />,
      perform: navigate('/admin/active_teenagers_leaderboard'),
    },
    {
      id: 'admin-new-teens-leaderboard',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'New teenagers leaderboard',
      icon: <Icon glyph="member-add" size={16} />,
      perform: navigate('/admin/new_teenagers_leaderboard'),
    },
    // airtable
    {
      id: 'admin-applications-airtable',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Applications (Airtable)',
      icon: <Icon glyph="align-left" size={16} />,
      perform: navigate(adminUrls['Applications']),
    },
    {
      id: 'admin-gsuite-waitlist',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Google Workspace waitlist',
      icon: <Icon glyph="google" size={16} />,
      perform: navigate(adminUrls['Google Workspace Waitlist']),
    },
    {
      id: 'admin-disputes',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Disputes',
      icon: <Icon glyph="important" size={16} />,
      perform: navigate(adminUrls['Disputes']),
    },
    {
      id: 'admin-feedback',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Feedback',
      icon: <Icon glyph="message-new" size={16} />,
      perform: navigate(adminUrls['Feedback']),
    },
    {
      id: 'admin-stickers',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Stickers',
      icon: <Icon glyph="sticker" size={16} />,
      perform: navigate(adminUrls['Stickers']),
    },
    {
      id: 'admin-hackathons',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Hackathons',
      icon: <Icon glyph="event-code" size={16} />,
      perform: navigate(adminUrls['Hackathons']),
    },
    {
      id: 'admin-1passwords',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: '1Password',
      icon: <Icon glyph="private" size={16} />,
      perform: navigate(adminUrls['1Password']),
    },
    {
      id: 'admin-domains',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Domains',
      icon: <Icon glyph="web" size={16} />,
      perform: navigate(adminUrls['Domains']),
    },
    {
      id: 'admin-event-helper',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'The Event Helper',
      icon: <Icon glyph="relaxed" size={16} />,
      perform: navigate(adminUrls['The Event Helper']),
    },
  ]
}

function navigate(to) {
  return () => {
    if (to.startsWith('https://')) {
      window.open(to, '_blank')
    } else {
      window.Turbo.visit(to)
    }
    window?.FS?.event('command_bar_navigation', {
      query: document.querySelector('[role="combobox"]').value,
      to,
    })
  }
}
