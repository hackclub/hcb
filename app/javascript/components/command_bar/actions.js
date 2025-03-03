/* eslint react/prop-types:0 */

import { Priority } from 'kbar'
import Icon from '@hackclub/icons'
import csrf from '../../common/csrf'
import React from 'react'

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
      icon: <Icon glyph="briefcase" size={16} />,
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
      name: 'Check deposit',
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
      icon: <Icon glyph="attachment" size={16} />,
      parent: event.slug,
    })),
    ...data.map(event => ({
      id: `${event.slug}-team`,
      name: 'Team',
      perform: navigate(`/${event.slug}/team`),
      icon: <Icon glyph="leader" size={16} />,
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
      id: `${event.slug}-documentation`,
      name: 'Documentation',
      perform: () =>
        (window.location.pathname = `/${event.slug}/documentation`),
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
    icon: <Icon glyph="payment-docs" size={16} />,
    priority: Priority.HIGH,
  },
  {
    id: 'settings',
    name: 'Settings',
    keywords: 'settings',
    perform: navigate('/my/settings'),
    section: 'Pages',
    icon: <Icon glyph="settings" size={16} />,
    priority: Priority.HIGH,
  },
  ...['light', 'dark', 'system'].map(theme => ({
    id: `${theme}-theme`,
    name: `Set theme to ${theme}`,
    keywords: theme, // eslint-disable-next-line no-undef
    perform: () => BK.setDark(theme),
    section: 'Actions',
    icon: <Icon glyph="idea" size={16} />,
    priority: Priority.HIGH,
  })),
  {
    id: 'signout',
    name: 'Sign Out',
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

export const adminActions = adminUrls => [
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
    name: 'OnBoard ID',
    icon: <Icon glyph="emoji" size={16} />,
    perform: () => (window.location.href = adminUrls['OnBoard ID']),
  },
  {
    id: 'admin_tool_3',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Ledger',
    icon: <Icon glyph="list" size={16} />,
    perform: () => (window.location.href = '/admin/ledger'),
  },
  {
    id: 'admin_tool_4',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'ACH',
    icon: <Icon glyph="payment-transfer" size={16} />,
    perform: () => (window.location.href = '/admin/ach'),
  },
  {
    id: 'admin_tool_5',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Check',
    icon: <Icon glyph="payment-docs" size={16} />,
    perform: () => (window.location.href = '/admin/increase_checks'),
  },
  {
    id: 'admin_tool_6',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Grants',
    icon: <Icon glyph="support" size={16} />,
    perform: () => (window.location.href = '/admin/grants'),
  },
  {
    id: 'admin_tool_7',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Wires',
    icon: <Icon glyph="web" size={16} />,
    perform: () => (window.location.href = '/admin/wires'),
  },
  {
    id: 'admin_tool_8',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'PayPal',
    icon: <Icon glyph="grid" size={16} />,
    perform: () => (window.location.href = '/admin/paypal_transfers'),
  },
  {
    id: 'admin_tool_9',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Disbursements',
    icon: <Icon glyph="payment-transfer" size={16} />,
    perform: () => (window.location.href = '/admin/disbursements'),
  },
  {
    id: 'admin_tool_10',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Deletion Requests',
    icon: <Icon glyph="member-remove" size={16} />,
    perform: () =>
      (window.location.href = '/organizer_position_deletion_requests'),
  },
  {
    id: 'admin_tool_11',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Disputes',
    icon: <Icon glyph="important" size={16} />,
    perform: () => (window.location.href = adminUrls['Disputes']),
  },
  {
    id: 'admin_tool_12',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Feedback',
    icon: <Icon glyph="message-new" size={16} />,
    perform: () => (window.location.href = adminUrls['Feedback']),
  },
  {
    id: 'admin_tool_14',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Organizations',
    icon: <Icon glyph="explore" size={16} />,
    perform: () => (window.location.href = '/admin/events'),
  },
  {
    id: 'admin_tool_15',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Users',
    icon: <Icon glyph="leaders" size={16} />,
    perform: () => (window.location.href = '/admin/users'),
  },
  {
    id: 'admin_tool_16',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Donations',
    icon: <Icon glyph="support" size={16} />,
    perform: () => (window.location.href = '/admin/donations'),
  },
  {
    id: 'admin_tool_17',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Invoices',
    icon: <Icon glyph="docs-fill" size={16} />,
    perform: () => (window.location.href = '/admin/invoices'),
  },
  {
    id: 'admin_tool_18',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Sponsors',
    icon: <Icon glyph="purse" size={16} />,
    perform: () => (window.location.href = '/admin/sponsors'),
  },
  {
    id: 'admin_tool_19',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Cards',
    icon: <Icon glyph="card" size={16} />,
    perform: () => (window.location.href = '/admin/stripe_cards'),
  },
  {
    id: 'admin_tool_20',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Google Workspaces',
    icon: <Icon glyph="google" size={16} />,
    perform: () => (window.location.href = '/admin/google_workspaces'),
  },
  {
    id: 'admin_tool_21',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Stickers',
    icon: <Icon glyph="sticker" size={16} />,
    perform: () => (window.location.href = adminUrls['Stickers']),
  },
  {
    id: 'admin_tool_22',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Wallets',
    icon: <Icon glyph="send" size={16} />,
    perform: () => (window.location.href = adminUrls['Wallets']),
  },
  {
    id: 'admin_tool_23',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Hackathons',
    icon: <Icon glyph="event-code" size={16} />,
    perform: () => (window.location.href = adminUrls['Hackathons']),
  },
  {
    id: 'admin_tool_25',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: '1Password',
    icon: <Icon glyph="private" size={16} />,
    perform: () => (window.location.href = adminUrls['1Password']),
  },
  {
    id: 'admin_tool_26',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Domains',
    icon: <Icon glyph="web" size={16} />,
    perform: () => (window.location.href = adminUrls['Domains']),
  },
  {
    id: 'admin_tool_27',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'PVSA',
    icon: <Icon glyph="thumbsup" size={16} />,
    perform: () => (window.location.href = adminUrls['PVSA']),
  },
  {
    id: 'admin_tool_28',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'The Event Helper',
    icon: <Icon glyph="relaxed" size={16} />,
    perform: () => (window.location.href = adminUrls['The Event Helper']),
  },
  {
    id: 'admin_tool_29',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Google Workspace waitlist',
    icon: <Icon glyph="google" size={16} />,
    perform: () =>
      (window.location.href = adminUrls['Google Workspace Waitlist']),
  },
  {
    id: 'admin_tool_30',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Bank Fees',
    icon: <Icon glyph="bank-circle" size={16} />,
    perform: navigate('/admin/bank_fees'),
  },
  {
    id: 'admin_tool_30',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Organization Balances',
    icon: <Icon glyph="payment" size={16} />,
    perform: navigate('/admin/balances'),
  },
  {
    id: 'admin_tool_31',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Check Deposits',
    icon: <Icon glyph="payment-docs" size={16} />,
    perform: navigate('/admin/check_deposits'),
  },
  {
    id: 'admin_tool_32',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Blazer',
    icon: <Icon glyph="bolt" size={16} />,
    perform: navigate('/blazer'),
  },
  {
    id: 'admin_tool_33',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Common Documents',
    icon: <Icon glyph="docs" size={16} />,
    perform: navigate('/documents'),
  },
  {
    id: 'admin_tool_34',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Pending Ledger',
    icon: <Icon glyph="list" size={16} />,
    perform: navigate('/admin/pending_ledger'),
  },
  {
    id: 'admin_tool_35',
    section: 'Admin Tools',
    priority: Priority.HIGH,
    name: 'Recurring Donations',
    icon: <Icon glyph="transactions" size={16} />,
    perform: navigate('/admin/recurring_donations'),
  },
]

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
