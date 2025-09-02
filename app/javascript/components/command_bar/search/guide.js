/* eslint react/prop-types:0 */

import React from 'react'

export function Guide() {
  return (
    <>
      <span style={{ color: 'var(--kbar-foreground)' }}>
        Use the{' '}
        <kbd
          style={{
            borderRadius: '3px',
            backgroundColor: 'var(--command-bar-user)',
            outline: '2px solid var(--command-bar-user)',
            paddingLeft: '3px',
            paddingRight: '3px',
            marginRight: '1.5px',
            color: 'black',
            border: 'none',
          }}
        >
          @user
        </kbd>
        ,{' '}
        <kbd
          style={{
            borderRadius: '3px',
            backgroundColor: 'var(--command-bar-transaction)',
            outline: '2px solid var(--command-bar-transaction)',
            paddingLeft: '3px',
            paddingRight: '3px',
            marginRight: '1.5px',
            color: 'black',
            border: 'none',
          }}
        >
          @transaction
        </kbd>
        ,{' '}
        <kbd
          style={{
            borderRadius: '3px',
            backgroundColor: 'var(--command-bar-organization)',
            outline: '2px solid var(--command-bar-organization)',
            paddingLeft: '3px',
            paddingRight: '3px',
            color: 'black',
            border: 'none',
          }}
        >
          @organization
        </kbd>
        ,{' '}
        <kbd
          style={{
            borderRadius: '3px',
            backgroundColor: 'var(--command-bar-reimbursement)',
            outline: '2px solid var(--command-bar-reimbursement)',
            paddingLeft: '3px',
            paddingRight: '3px',
            color: 'black',
            border: 'none'
          }}
        >
          @reimbursement
        </kbd>{' '}
        and{' '}
        <kbd
          style={{
            borderRadius: '3px',
            backgroundColor: 'var(--command-bar-card)',
            outline: '2px solid var(--command-bar-card)',
            paddingLeft: '3px',
            paddingRight: '3px',
            color: 'black',
            border: 'none'
          }}
        >
          @card
        </kbd>{' '}
        tags to narrow down your search. To search, click enter.
      </span>
    </>
  )
}
