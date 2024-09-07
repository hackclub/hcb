/* eslint react/prop-types:0 */

import React from 'react'
import Icon from '@hackclub/icons'
import { Priority } from 'kbar'
import Intl from 'intl'
import 'intl/locale-data/jsonp/en-US'

export const USDollar = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
})

export function generateResultActions(results, searchedFor) {
  return results.map(result => {
    switch (result.type) {
      case 'Event':
        return {
          id: `result`,
          parent: `results: ${searchedFor}`,
          perform: () => (window.location.pathname = result.path),
          name: `${result.label}`,
          jsx: (
            <>
              <span
                style={{
                  borderRadius: '3px',
                  backgroundColor: 'var(--command-bar-organization)',
                  outline: '2px solid var(--command-bar-organization)',
                  paddingLeft: '3px',
                  paddingRight: '3px',
                  marginRight: '4px',
                }}
              >
                {USDollar.format(Math.abs(result.balance / 100))}
              </span>{' '}
              {result.label}
            </>
          ),
          icon: result.image ? (
            <img
              src={result.image}
              height="16px"
              width="16px"
              style={{ borderRadius: '4px' }}
            />
          ) : (
            <Icon glyph="bank-account" size={16} />
          ),

          priority: Priority.HIGH,
        }
      case 'User':
        return {
          id: `result`,
          parent: `results: ${searchedFor}`,
          perform: () => (window.location.pathname = result.path),
          name: result.label,
          icon:
            result.image && result.image != 'none' ? (
              <img
                src={result.image}
                height="16px"
                width="16px"
                style={{ borderRadius: '4px' }}
              />
            ) : (
              <Icon glyph="emoji" size={16} />
            ),
          priority: Priority.HIGH,
        }
      case 'CanonicalTransaction':
        return {
          id: `result`,
          parent: `results: ${searchedFor}`,
          name: `${result.event} ${result.user} ${result.label}`,
          perform: () => (window.location.pathname = result.path),
          jsx: (
            <>
              <span
                style={{
                  borderRadius: '3px',
                  backgroundColor: 'var(--command-bar-organization)',
                  outline: '2px solid var(--command-bar-organization)',
                  paddingLeft: '3px',
                  paddingRight: '3px',
                  marginRight: '4px',
                }}
              >
                {result.event || 'Unknown'}
              </span>{' '}
              {result.user && (
                <span
                  style={{
                    borderRadius: '3px',
                    backgroundColor: 'var(--command-bar-organization)',
                    outline: '2px solid var(--command-bar-organization)',
                    paddingLeft: '3px',
                    paddingRight: '3px',
                    marginRight: '4px',
                  }}
                >
                  {result.user || 'Unknown'}
                </span>
              )}{' '}
              <span
                style={{
                  borderRadius: '3px',
                  backgroundColor: 'var(--command-bar-transaction)',
                  outline: '2px solid var(--command-bar-transaction)',
                  paddingLeft: '3px',
                  paddingRight: '3px',
                  marginRight: '6px',
                }}
              >
                {USDollar.format(Math.abs(result.amount_cents / 100))}
              </span>{' '}
              {result.label}
            </>
          ),
          icon: <Icon glyph="transactions" size={16} />,
          priority: Priority.HIGH,
        }
      case 'StripeCard':
        return {
          id: `result`,
          parent: `results: ${searchedFor}`,
          perform: () => (window.location.pathname = result.path),
          name: `${result.event} ${result.user} ${result.label}`,
          jsx: (
            <>
              <span
                style={{
                  borderRadius: '3px',
                  backgroundColor: 'var(--command-bar-organization)',
                  outline: '2px solid var(--command-bar-organization)',
                  paddingLeft: '3px',
                  paddingRight: '3px',
                  marginRight: '4px',
                }}
              >
                {result.event || 'Unknown'}
              </span>{' '}
              {result.user && (
                <span
                  style={{
                    borderRadius: '3px',
                    backgroundColor: 'var(--command-bar-user)',
                    outline: '2px solid var(--command-bar-user)',
                    paddingLeft: '3px',
                    paddingRight: '3px',
                    marginRight: '4px',
                  }}
                >
                  {result.user || 'Unknown'}
                </span>
              )}{' '}
              •••• •••• •••• {result.label}
            </>
          ),
          icon: <Icon glyph="card" size={16} />,
          priority: Priority.HIGH,
        }
      case 'Reimbursement::Report':
        return {
          id: `result`,
          parent: `results: ${searchedFor}`,
          perform: () => (window.location.pathname = result.path),
          name: `${result.event} ${result.user} ${result.label}`,
          jsx: (
            <>
              <span
                style={{
                  borderRadius: '3px',
                  backgroundColor: 'var(--command-bar-organization)',
                  outline: '2px solid var(--command-bar-organization)',
                  paddingLeft: '3px',
                  paddingRight: '3px',
                  marginRight: '4px',
                }}
              >
                {result.event || 'Unknown'}
              </span>{' '}
              {result.user && (
                <span
                  style={{
                    borderRadius: '3px',
                    backgroundColor: 'var(--command-bar-user)',
                    outline: '2px solid var(--command-bar-user)',
                    paddingLeft: '3px',
                    paddingRight: '3px',
                    marginRight: '4px',
                  }}
                >
                  {result.user || 'Unknown'}
                </span>
              )}{' '}
              {result.label}
            </>
          ),
          icon: <Icon glyph="attachment" size={16} />,
          priority: Priority.HIGH,
        }
    }
  })
}
