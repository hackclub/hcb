/* eslint react/prop-types:0 */

import { Priority } from 'kbar'
import Icon from '@hackclub/icons'
import csrf from '../../common/csrf'
import React from 'react'
import ReimbursementIcon from '../icons/reimbursement'

const restrictedFilter = e => !e.demo_mode

export const generateEventActions = data => {
  console.log(data)
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
      perform: () =>
        (window.location.pathname = `/${event.slug}/announcements`),
      icon: <Icon glyph="announcement" size={16} />,
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
      id: `${event.slug}-account-number`,
      name: 'Account numbers',
      perform: () =>
        (window.location.pathname = `/${event.slug}/account-number`),
      icon: <Icon glyph="bank-account" size={16} />,
      parent: event.slug,
    })),
    ...data.filter(restrictedFilter).map(event => ({
      id: `${event.slug}-check-deposit`,
      name: 'Check deposits',
      perform: () =>
        (window.location.pathname = `/${event.slug}/check-deposits`),
      icon: <Icon glyph="attachment" size={16} />,
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
      icon: <ReimbursementIcon size={16} />,
      parent: event.slug,
    })),
    ...data.map(event => ({
      id: `${event.slug}-team`,
      name: 'Team',
      perform: navigate(`/${event.slug}/team`),
      icon: <Icon glyph="leader" size={16} />,
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
      id: `${event.slug}-perks`,
      name: 'Perks',
      perform: navigate(`/${event.slug}/promotions`),
      icon: <Icon glyph="shirt" size={16} />,
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
      perform: () => (window.location.pathname = `/${event.slug}/documents`),
      icon: <Icon glyph="info" size={16} />,
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
    id: 'home',
    name: 'Home',
    keywords: 'index',
    perform: navigate('/'),
    icon: <Icon glyph="home" size={16} />,
    section: 'Pages',
    priority: Priority.HIGH,
  },
  {
    id: 'cards',
    name: 'Cards',
    keywords: 'cards',
    perform: navigate('/my/cards'),
    section: 'Pages',
    icon: <Icon glyph="card" size={16} />,
    priority: Priority.HIGH,
  },
  {
    id: 'receipts',
    name: 'Receipts',
    keywords: 'receipts inbox',
    perform: navigate('/my/inbox'),
    section: 'Pages',
    icon: <Icon glyph="docs" size={16} />,
    priority: Priority.HIGH,
  },
  {
    id: 'reimbursements',
    name: 'Reimbursements',
    keywords: 'reimbursements report',
    perform: navigate('/my/reimbursements'),
    section: 'Pages',
    icon: <Icon glyph="attachment" size={16} />,
    priority: Priority.HIGH,
  },
  {
    id: 'settings',
    name: 'Settings',
    keywords: 'settings',
    section: 'Pages',
    icon: <Icon glyph="settings" size={16} />,
    priority: Priority.HIGH,
  },
  {
    id: 'settings-account',
    name: 'Account',
    keywords: 'account profile personal name birthday picture email sign',
    perform: navigate('/my/settings'),
    parent: 'settings',
    icon: <Icon glyph="profile" size={16} />,
    priority: Priority.HIGH,
  },
  {
    id: 'settings-notifications',
    name: 'Notifications',
    keywords: 'notifications alerts emails',
    perform: navigate('/my/settings/notifications'),
    parent: 'settings',
    icon: <Icon glyph="notification" size={16} />,
    priority: Priority.HIGH,
  },
  {
    id: 'settings-payouts',
    name: 'Payout settings',
    keywords: 'reimbursement payouts payment bank direct deposit',
    perform: navigate('/my/settings/payouts'),
    parent: 'settings',
    icon: <Icon glyph="payment-transfer" size={16} />,
    priority: Priority.HIGH,
  },
  {
    id: 'settings-security',
    name: 'Security',
    keywords: 'security password authentication 2fa two-factor',
    perform: navigate('/my/settings/security'),
    parent: 'settings',
    icon: <Icon glyph="private" size={16} />,
    priority: Priority.HIGH,
  },
  {
    id: 'settings-previews',
    name: 'Feature previews',
    keywords: 'feature previews beta experimental',
    perform: navigate('/my/settings/previews'),
    parent: 'settings',
    icon: <Icon glyph="rep" size={16} />,
    priority: Priority.HIGH,
  },
  ...['light', 'dark', 'system'].map(theme => ({
    id: `${theme}-theme`,
    name: `Set theme to ${theme}`,
    section: 'Actions',
    icon: <Icon glyph="idea" size={16} />,
    keywords: theme, // eslint-disable-next-line no-undef
    perform: () => BK.setDark(theme),
  })),
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
        id: 'pretend',
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
      id: 'pretend',
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
    {
      id: 'admin_tool_1',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Applications',
      icon: <Icon glyph="align-left" size={16} />,
      perform: () => (window.location.href = adminUrls['Applications']),
    },
    {
      id: 'admin_tool_2',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Ledger',
      icon: <Icon glyph="list" size={16} />,
      perform: () => (window.location.href = '/admin/ledger'),
    },
    {
      id: 'admin_tool_3',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'ACH transfers',
      icon: <Icon glyph="payment-transfer" size={16} />,
      perform: () => (window.location.href = '/admin/ach'),
    },
    {
      id: 'admin_tool_4',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Checks',
      icon: <Icon glyph="payment-docs" size={16} />,
      perform: () => (window.location.href = '/admin/increase_checks'),
    },
    {
      id: 'admin_tool_5',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Wires',
      icon: <Icon glyph="web" size={16} />,
      perform: () => (window.location.href = '/admin/wires'),
    },
    {
      id: 'admin_tool_6',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Disbursements',
      icon: <Icon glyph="payment-transfer" size={16} />,
      perform: () => (window.location.href = '/admin/disbursements'),
    },
    {
      id: 'admin_tool_7',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Organizer position deletion requests',
      icon: <Icon glyph="member-remove" size={16} />,
      perform: () =>
        (window.location.href = '/organizer_position_deletion_requests'),
    },
    {
      id: 'admin_tool_8',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Disputes',
      icon: <Icon glyph="important" size={16} />,
      perform: () => (window.location.href = adminUrls['Disputes']),
    },
    {
      id: 'admin_tool_9',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Feedback',
      icon: <Icon glyph="message-new" size={16} />,
      perform: () => (window.location.href = adminUrls['Feedback']),
    },
    {
      id: 'admin_tool_10',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Organizations',
      icon: <Icon glyph="explore" size={16} />,
      perform: () => (window.location.href = '/admin/events'),
    },
    {
      id: 'admin_tool_11',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Users',
      icon: <Icon glyph="leaders" size={16} />,
      perform: () => (window.location.href = '/admin/users'),
    },
    {
      id: 'admin_tool_12',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Donations',
      icon: <Icon glyph="support" size={16} />,
      perform: () => (window.location.href = '/admin/donations'),
    },
    {
      id: 'admin_tool_13',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Invoices',
      icon: <Icon glyph="docs-fill" size={16} />,
      perform: () => (window.location.href = '/admin/invoices'),
    },
    {
      id: 'admin_tool_14',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Sponsors',
      icon: <Icon glyph="purse" size={16} />,
      perform: () => (window.location.href = '/admin/sponsors'),
    },
    {
      id: 'admin_tool_15',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Cards',
      icon: <Icon glyph="card" size={16} />,
      perform: () => (window.location.href = '/admin/stripe_cards'),
    },
    {
      id: 'admin_tool_16',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Google Workspaces',
      icon: <Icon glyph="google" size={16} />,
      perform: () => (window.location.href = '/admin/google_workspaces'),
    },
    {
      id: 'admin_tool_17',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Stickers',
      icon: <Icon glyph="sticker" size={16} />,
      perform: () => (window.location.href = adminUrls['Stickers']),
    },
    {
      id: 'admin_tool_18',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Hackathons',
      icon: <Icon glyph="event-code" size={16} />,
      perform: () => (window.location.href = adminUrls['Hackathons']),
    },
    {
      id: 'admin_tool_19',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: '1Password',
      icon: <Icon glyph="private" size={16} />,
      perform: () => (window.location.href = adminUrls['1Password']),
    },
    {
      id: 'admin_tool_20',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Domains',
      icon: <Icon glyph="web" size={16} />,
      perform: () => (window.location.href = adminUrls['Domains']),
    },
    {
      id: 'admin_tool_21',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'The Event Helper',
      icon: <Icon glyph="relaxed" size={16} />,
      perform: () => (window.location.href = adminUrls['The Event Helper']),
    },
    {
      id: 'admin_tool_22',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Google Workspace waitlist',
      icon: <Icon glyph="google" size={16} />,
      perform: () =>
        (window.location.href = adminUrls['Google Workspace Waitlist']),
    },
    {
      id: 'admin_tool_23',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Bank fees',
      icon: <Icon glyph="bank-circle" size={16} />,
      perform: navigate('/admin/bank_fees'),
    },
    {
      id: 'admin_tool_24',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Organization balances',
      icon: <Icon glyph="payment" size={16} />,
      perform: navigate('/admin/balances'),
    },
    {
      id: 'admin_tool_25',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Check deposits',
      icon: <Icon glyph="payment-docs" size={16} />,
      perform: navigate('/admin/check_deposits'),
    },
    {
      id: 'admin_tool_26',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Blazer',
      icon: <Icon glyph="bolt" size={16} />,
      perform: navigate('/blazer'),
    },
    {
      id: 'admin_tool_27',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Common documents',
      icon: <Icon glyph="docs" size={16} />,
      perform: navigate('/documents'),
    },
    {
      id: 'admin_tool_28',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Pending ledger',
      icon: <Icon glyph="list" size={16} />,
      perform: navigate('/admin/pending_ledger'),
    },
    {
      id: 'admin_tool_29',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Recurring donations',
      icon: <Icon glyph="transactions" size={16} />,
      perform: navigate('/admin/recurring_donations'),
    },
    {
      id: 'admin_tool_30',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Flipper',
      icon: <Icon glyph="flag-fill" size={16} />,
      perform: navigate('/flipper/features'),
    },
    {
      id: 'admin_tool_31',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Referral programs',
      icon: <Icon glyph="share" size={16} />,
      perform: navigate('/admin/referral_programs'),
    },
    {
      id: 'admin_tool_32',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'Active teenagers leaderboard',
      icon: <Icon glyph="leader" size={16} />,
      perform: navigate('/admin/active_teenagers_leaderboard'),
    },
    {
      id: 'admin_tool_33',
      section: 'Admin Tools',
      priority: Priority.HIGH,
      name: 'New teenagers leaderboard',
      icon: <Icon glyph="member-add" size={16} />,
      perform: navigate('/admin/new_teenagers_leaderboard'),
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
