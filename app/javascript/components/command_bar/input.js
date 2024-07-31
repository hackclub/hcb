/* eslint react/prop-types:0 */

import { RichTextarea, createRegexRenderer } from 'rich-textarea'
import React, { useState, useEffect } from 'react'
import { useKBar } from 'kbar'

const renderer = createRegexRenderer([
  [
    /@org(?=\s|$)/g,
    {
      borderRadius: '3px',
      backgroundColor: 'var(--command-bar-organization)',
      outline: '2px solid var(--command-bar-organization)',
    },
  ],
  [
    /@txn:(.*?)(?=\s|$)/g,
    {
      borderRadius: '3px',
      backgroundColor: 'var(--command-bar-transaction)',
      outline: '2px solid var(--command-bar-transaction)',
    },
  ],
  [
    /@transaction:(.*?)(?=\s|$)/g,
    {
      borderRadius: '3px',
      backgroundColor: 'var(--command-bar-transaction)',
      outline: '2px solid var(--command-bar-transaction)',
    },
  ],
  [
    /@organisation(?=\s|$)/g,
    {
      borderRadius: '3px',
      backgroundColor: 'var(--command-bar-organization)',
      outline: '2px solid var(--command-bar-organization)',
    },
  ],
  [
    /@organization(?=\s|$)/g,
    {
      borderRadius: '3px',
      backgroundColor: 'var(--command-bar-organization)',
      outline: '2px solid var(--command-bar-organization)',
    },
  ],
  [
    /@txn(?=\s|$)/g,
    {
      borderRadius: '3px',
      backgroundColor: 'var(--command-bar-transaction)',
      outline: '2px solid var(--command-bar-transaction)',
    },
  ],
  [
    /@transaction(?=\s|$)/g,
    {
      borderRadius: '3px',
      backgroundColor: 'var(--command-bar-transaction)',
      outline: '2px solid var(--command-bar-transaction)',
    },
  ],
  [
    /@user(?=\s|$)/g,
    {
      borderRadius: '3px',
      backgroundColor: 'var(--command-bar-user)',
      outline: '2px solid var(--command-bar-user)',
    },
  ],
  [
    /@card(?=\s|$)/g,
    {
      borderRadius: '3px',
      backgroundColor: 'var(--command-bar-card)',
      outline: '2px solid var(--command-bar-card)',
    },
  ],
  [
    /@reimbursement(?=\s|$)/g,
    {
      borderRadius: '3px',
      backgroundColor: 'var(--command-bar-reimbursement)',
      outline: '2px solid var(--command-bar-reimbursement)',
    },
  ],
  [/\[[^\]]*\]/g, { borderRadius: '3px', backgroundColor: '#abdea9' }],
])

export function KBarInput(props) {
  const { query, search, actions, currentRootActionId, showing, options } =
    useKBar(state => ({
      search: state.searchQuery,
      currentRootActionId: state.currentRootActionId,
      actions: state.actions,
      showing: state.visualState === 'showing',
    }))

  const [inputValue, setInputValue] = useState(search)

  useEffect(() => {
    query.setSearch(inputValue)
  }, [inputValue, query])

  const { defaultPlaceholder, placeholder, searching, searched, ...rest } =
    props

  useEffect(() => {
    query.setSearch('')
    setInputValue('')
    query.getInput().focus()
    return () => query.setSearch('')
  }, [currentRootActionId, query])

  const calculatedPlaceholder = React.useMemo(() => {
    const defaultText = defaultPlaceholder ?? 'Type a command or search…'
    return (
      placeholder ||
      (currentRootActionId && actions[currentRootActionId]
        ? actions[currentRootActionId].label ||
          actions[currentRootActionId].name
        : defaultText)
    )
  }, [actions, currentRootActionId, defaultPlaceholder, placeholder])

  return (
    <div style={{ marginBottom: '-8px' }}>
      <RichTextarea
        {...rest}
        style={{
          padding: '12px 16px',
          fontSize: '16px',
          width: '100%',
          boxSizing: 'border-box',
          outline: 'none',
          border: 'none',
          background: 'var(--kbar-background)',
          color: 'var(--kbar-foreground)',
          maxWidth: '600px',
          resize: 'none',
          fontStyle: calculatedPlaceholder == 'Loading...' ? 'italic' : '',
        }}
        ref={query.inputRefSetter}
        autoFocus
        autoComplete="off"
        role="combobox"
        spellCheck="false"
        aria-expanded={showing}
        aria-controls={'kbar-listbox'}
        aria-activedescendant={id => `kbar-listbox-item-${id}`}
        value={inputValue}
        placeholder={calculatedPlaceholder}
        disabled={calculatedPlaceholder == 'Loading...'}
        rows="1"
        wrap="off"
        className="kbar-textarea"
        onChange={event => {
          props.onChange?.(event)
          setInputValue(event.target.value)
          options?.callbacks?.onQueryChange?.(event.target.value)
        }}
        onKeyDown={event => {
          props.onKeyDown?.(event)
          if (currentRootActionId && !search && event.key === 'Backspace') {
            const parent = actions[currentRootActionId].parent
            query.setCurrentRootAction(parent)
          }
        }}
      >
        {(searching || searched) && renderer}
      </RichTextarea>
    </div>
  )
}
