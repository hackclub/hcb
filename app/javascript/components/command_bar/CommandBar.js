/* eslint react/prop-types:0 */

import React, { useState, useEffect } from 'react'
import {
  KBarProvider,
  KBarPortal,
  KBarPositioner,
  KBarAnimator,
  useRegisterActions,
  Priority,
  useKBar,
  useMatches,
} from 'kbar'
import { initalActions, adminActions, generateEventActions } from './actions'
import { KBarInput } from './input'
import { RenderResults } from './results'
import { generateResultActions } from './search/results'
import Icon from '@hackclub/icons'

export default function CommandBar({
  admin = false,
  admin_override_pretend = false,
  adminUrls = {},
}) {
  return (
    <div style={{ position: 'relative', zIndex: '100000000' }}>
      <KBarProvider
        actions={[
          ...initalActions,
          ...(admin || admin_override_pretend
            ? adminActions(adminUrls, !admin && admin_override_pretend)
            : []),
        ]}
        options={{
          disableScrollbarManagement: true,
          disableDocumentLock: true,
        }}
      >
        <ButtonTrigger />
        <KBarPortal>
          <KBarPositioner
            style={{ zIndex: 1000, backgroundColor: 'var(--kbar-dim)' }}
          >
            <SearchAndResults />
          </KBarPositioner>
        </KBarPortal>
      </KBarProvider>
    </div>
  )
}

const ButtonTrigger = () => {
  const { query } = useKBar()
  document
    .querySelectorAll(`[data-behavior="command_bar_trigger"]`)
    .forEach(trigger => {
      trigger.onclick = function () {
        query.toggle()
      }
    })
}

const animatorStyle = {
  maxWidth: '600px',
  width: '100%',
  background: 'var(--kbar-background)',
  color: 'var(--kbar-foreground)',
  borderRadius: 'var(--radius-xl)',
  overflow: 'hidden',
  boxShadow: 'var(--shadow-modal)',
}

function EmptyState() {
  const { results } = useMatches()

  return (
    results.length === 0 && (
      <div className="text-center font-semibold pt-4 pb-5">
        <img
          src="/dino_leaping_for_money.svg"
          className="dino-svg mb-4 mx-auto w-100 block max-w-40"
        />
        No results found
      </div>
    )
  )
}

function SearchAndResults() {
  const [actions, setActions] = useState([])
  const { search, searching, searched, searchedFor, currentRootActionId } =
    useKBar(state => {
      return {
        state,
        search: state.currentRootActionId?.startsWith('search')
          ? state.searchQuery
          : null,
        searching: state.currentRootActionId?.startsWith('search'),
        searched: state.currentRootActionId?.startsWith('results:'),
        searchedFor: state.currentRootActionId?.startsWith('results:')
          ? state.currentRootActionId?.replace('results: ', '')
          : '',
        currentRootActionId: state.currentRootActionId,
      }
    })

  useRegisterActions(actions, [actions])

  useEffect(() => {
    async function fetchOrganizations() {
      try {
        const response = await fetch('/events.json')
        if (response.ok) {
          const data = await response.json()
          setActions([...actions, ...generateEventActions(data)])
        }
      } catch (error) {
        console.error('Error:', error)
      }
    }
    fetchOrganizations()
  }, [])

  useEffect(() => {
    if (search != null) {
      setActions([
        ...actions.filter(
          a =>
            !a.id?.startsWith('results:') && !a.parent?.startsWith('results:')
        ),
        ...(search != ''
          ? [
              {
                id: 'search',
                name: 'Search',
                keywords: 'search',
                icon: <Icon glyph="search" size={16} />,
                priority: Priority.HIGH,
              },
              {
                id: `results: ${search}`,
                parent: currentRootActionId,
                name: `Loading...`,
                keywords: search,
                priority: Priority.HIGH,
              },
            ]
          : []),
      ])
    }
  }, [search])

  useEffect(() => {
    async function fetchResults() {
      try {
        const response = await fetch(`/search.json?query=${searchedFor}`)
        if (response.ok) {
          const data = await response.json()
          if (data.error) {
            setActions([
              ...actions,
              {
                id: 'search',
                parent: `results: ${searchedFor}`,
                jsx: (
                  <span style={{ color: '#8492a6' }}>
                    Error: {data.error} Try again?
                  </span>
                ),
                name: 'error',
                label: 'Search...',
                keywords: 'search',
                icon: <Icon glyph="important" size={16} color="#8492a6" />,
                priority: Priority.LOW,
              },
            ])
          } else {
            let generatedActions = generateResultActions(data, searchedFor)
            setActions([
              ...actions,
              ...generatedActions,
              {
                id: 'search',
                parent: `results: ${searchedFor}`,
                name: generatedActions.length > 0 ? 'new search' : 'error',
                jsx: (
                  <span style={{ color: '#8492a6' }}>
                    Not what you were looking for? Make a new search.
                  </span>
                ),
                label: 'Search...',
                keywords: 'search',
                icon: <Icon glyph="search" size={16} color="#8492a6" />,
                priority: Priority.LOW,
              },
            ])
          }
        }
      } catch {
        setActions([
          ...actions.filter(a => !a.id?.startsWith('loading')),
          {
            id: 'search',
            parent: `results: ${searchedFor}`,
            jsx: (
              <span style={{ color: '#8492a6' }}>
                An unexpected error occurred. Try again?
              </span>
            ),
            name: 'error',
            label: 'Search...',
            keywords: 'error',
            icon: <Icon glyph="important" size={16} color="#8492a6" />,
            priority: Priority.LOW,
          },
        ])
      }
    }

    if (searched == true) {
      fetchResults()
    }
  }, [searched])

  return (
    <KBarAnimator style={animatorStyle}>
      <KBarInput
        defaultPlaceholder={'Search for organizations, pages, actions...'}
        placeholder={
          searched && actions.filter(x => x.id == 'result').length > 0
            ? `Successfully found ${
                actions.filter(x => x.id == 'result').length
              } result${
                actions.filter(x => x.id == 'result').length > 1 ? 's' : ''
              }.`
            : searched && actions.filter(x => x.error).length > 0
              ? searchedFor
              : searched &&
                  actions.filter(
                    x =>
                      x.id == 'search' && x.parent == `results: ${searchedFor}`
                  ).length > 0
                ? 'Found 0 results.'
                : null
        }
        searching={searching}
        searched={searched}
      />
      <RenderResults />
      <EmptyState />
    </KBarAnimator>
  )
}
