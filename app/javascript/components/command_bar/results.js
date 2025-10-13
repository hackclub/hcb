/* eslint react/prop-types:0 */

import React from 'react'
import { KBarResults, useMatches } from 'kbar'
import { Guide } from './search/guide'

export function RenderResults() {
  const { results, rootActionId } = useMatches()
  return (
    <KBarResults
      items={
        results.length > 0 || !rootActionId?.startsWith('search')
          ? results
          : ['search_guide']
      }
      onRender={({ item, active }) =>
        typeof item === 'string' ||
        item.id?.startsWith('loading') ||
        item.id?.startsWith('results:') ? (
          <div
            style={
              (typeof item === 'string' && item == 'search_guide') ||
              item.id?.startsWith('results:')
                ? {
                    padding: '8px 16px',
                    color: 'rgba(0, 0, 0, 0.5)',
                  }
                : {
                    padding: '8px 16px',
                    fontSize: '10px',
                    textTransform: 'uppercase',
                    opacity: 0.5,
                  }
            }
          >
            {typeof item === 'string' && item != 'search_guide' ? (
              item
            ) : item == 'search_guide' || item.id?.startsWith('results:') ? (
              <Guide />
            ) : (
              'Loading...'
            )}
          </div>
        ) : (
          <ResultItem
            action={item}
            active={active}
            currentRootActionId={rootActionId}
          />
        )
      }
    />
  )
}

const ResultItem = React.forwardRef(
  ({ action, active, currentRootActionId }, ref) => {
    const ancestors = React.useMemo(() => {
      if (!currentRootActionId) return action.ancestors
      const index = action.ancestors.findIndex(
        ancestor => ancestor.id === currentRootActionId
      )
      return action.ancestors.slice(index + 1)
    }, [action.ancestors, currentRootActionId])

    return (
      <div
        ref={ref}
        style={{
          padding: '12px 16px',
          background: active
            ? action.section == 'Admin Tools'
              ? 'var(--kbar-admin-overlay)'
              : 'var(--kbar-overlay)'
            : action.section == 'Admin Tools'
              ? 'var(--kbar-admin-overlay)'
              : 'transparent',
          borderLeft: `2px solid ${
            active && action.name != 'error' && action.name != 'new search'
              ? action.section == 'Admin Tools'
                ? '#ff8c37'
                : '#ec3750'
              : 'transparent'
          }`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          cursor: 'pointer',
        }}
      >
        <div
          style={{
            display: 'flex',
            gap: '8px',
            alignItems: 'center',
            fontSize: 14,
          }}
        >
          {action.icon && (
            <div
              style={{
                opacity: active ? 1 : 0.6,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                transform: 'scale(1.2)',
              }}
            >
              {action.icon}
            </div>
          )}
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            <div>
              {ancestors.length > 0 &&
                ancestors.map(ancestor => (
                  <React.Fragment key={ancestor.id}>
                    <span
                      style={{
                        opacity: 0.5,
                        marginRight: 8,
                      }}
                    >
                      {ancestor.name}
                    </span>
                    <span
                      style={{
                        marginRight: 8,
                      }}
                    >
                      &rsaquo;
                    </span>
                  </React.Fragment>
                ))}
              <span>{action.jsx || action.name}</span>
            </div>
            {action.subtitle && (
              <span style={{ fontSize: 12 }}>{action.subtitle}</span>
            )}
          </div>
        </div>
        {action.shortcut?.length ? (
          <div
            aria-hidden
            style={{ display: 'grid', gridAutoFlow: 'column', gap: '4px' }}
          >
            {action.shortcut.map(sc => (
              <kbd
                key={sc}
                style={{
                  padding: '4px 6px',
                  background: 'rgba(0 0 0 / .1)',
                  borderRadius: '4px',
                  fontSize: 14,
                }}
              >
                {sc}
              </kbd>
            ))}
          </div>
        ) : null}
      </div>
    )
  }
)

ResultItem.displayName = 'ResultItem'
