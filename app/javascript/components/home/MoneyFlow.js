import { sankey, sankeyLeft, sankeyLinkHorizontal } from 'd3-sankey'
import PropTypes from 'prop-types'
import React, { useEffect, useId, useMemo, useRef, useState } from 'react'
import { USDollar, USDollarNoCents, useDarkMode } from './utils'

// Node kinds come from BreakdownEngine::MoneyFlow: income → hub → (group →) expense,
// plus a balance node on whichever side makes the two sides add up.
// Green/red passes contrast on both card surfaces, but its colorblind separation is
// only at the floor, so sides must also stay distinguishable by position and labels.
const COLORS = {
  income: '#0f9d74',
  hub: '#8492a6',
  balance: '#8492a6',
  group: '#ec3750',
  expense: '#ec3750',
}

const NODE_WIDTH = 8
// Room for a two-line label between adjacent nodes, however thin they are
const NODE_PADDING = 34
const ROW_HEIGHT = 52
// Below this, four columns don't fit, so the spending groups aren't broken down
const COMPACT_WIDTH = 560
const LABEL_FONT_SIZE = 13
const AVERAGE_CHARACTER_WIDTH = 7

const truncate = (text, maxCharacters) =>
  text.length > maxCharacters
    ? `${text.slice(0, Math.max(maxCharacters - 1, 1))}…`
    : text

function useWidth(ref) {
  const [width, setWidth] = useState(0)

  useEffect(() => {
    const observer = new ResizeObserver(([entry]) =>
      setWidth(entry.contentRect.width)
    )
    observer.observe(ref.current)

    return () => observer.disconnect()
  }, [ref])

  return width
}

// Turns each spending group into a terminal node by dropping its breakdown
function collapseGroups(data) {
  const isGroup = index => data.nodes[index].kind === 'group'
  const isBreakdown = index =>
    data.links.some(link => link.target === index && isGroup(link.source))

  const kept = data.nodes
    .map((node, index) => ({ node, index }))
    .filter(({ index }) => !isBreakdown(index))
  const newIndexes = new Map(
    kept.map(({ index }, newIndex) => [index, newIndex])
  )

  return {
    nodes: kept.map(({ node }) =>
      node.kind === 'group' ? { ...node, kind: 'expense' } : node
    ),
    links: data.links
      .filter(link => !isGroup(link.source))
      .map(link => ({
        ...link,
        source: newIndexes.get(link.source),
        target: newIndexes.get(link.target),
      })),
  }
}

function layout(fullData, width) {
  const compact = width < COMPACT_WIDTH
  const data = compact ? collapseGroups(fullData) : fullData

  const sources = new Set(data.links.map(link => link.source))
  const targets = new Set(data.links.map(link => link.target))
  const tallestColumn = Math.max(
    data.nodes.filter((_, i) => !targets.has(i)).length,
    data.nodes.filter((_, i) => !sources.has(i)).length,
    1
  )
  const height = Math.max(320, tallestColumn * ROW_HEIGHT)
  const labelMargin = compact ? 80 : width < 720 ? 104 : 128
  // Compact charts label the hub above its bar, as there's no room beside it
  const top = compact ? 44 : 24

  const graph = sankey()
    .nodeAlign(sankeyLeft)
    .nodeWidth(NODE_WIDTH)
    .nodePadding(NODE_PADDING)
    // Keep the engine's ordering (largest first, "Other" and "Balance" last)
    .nodeSort(null)
    .linkSort(null)
    .extent([
      [labelMargin, top],
      [width - labelMargin, height - 8],
    ])({
    nodes: data.nodes.map(node => ({ ...node })),
    links: data.links.map(link => ({ ...link })),
  })

  const columns = [...new Set(graph.nodes.map(node => node.x0))].sort(
    (a, b) => a - b
  )
  const columnGap =
    columns.length > 1 ? columns[1] - columns[0] - NODE_WIDTH : 0
  const hub = graph.nodes.find(node => node.kind === 'hub')

  return {
    ...graph,
    height,
    compact,
    labelMargin,
    columnGap,
    leftEdge: columns[0],
    rightEdge: columns[columns.length - 1],
    hub,
  }
}

function labelPosition(node, graph) {
  const isOuterColumn =
    node.x0 === graph.leftEdge || node.x0 === graph.rightEdge
  const space = isOuterColumn ? graph.labelMargin : graph.columnGap

  if (node.kind === 'hub' && graph.compact) {
    return {
      x: (node.x0 + node.x1) / 2,
      y: node.y0 - 26,
      anchor: 'middle',
      maxWidth: graph.columnGap * 2,
    }
  }

  const onLeft =
    node.x0 === graph.leftEdge || node.kind === 'hub' || node.kind === 'group'

  return {
    x: onLeft ? node.x0 - 6 : node.x1 + 6,
    y: (node.y0 + node.y1) / 2 - 2,
    anchor: onLeft ? 'end' : 'start',
    maxWidth: space - 12,
  }
}

function NodeLabel({ node, graph, colors }) {
  const { x, y, anchor, maxWidth } = labelPosition(node, graph)
  const maxCharacters = Math.floor(maxWidth / AVERAGE_CHARACTER_WIDTH)
  const isSpending = node.kind === 'group' || node.kind === 'expense'

  return (
    <text
      x={x}
      y={y}
      textAnchor={anchor}
      fontSize={LABEL_FONT_SIZE}
      fill={colors.text}
      stroke={colors.surface}
      strokeWidth={3}
      strokeLinejoin="round"
      paintOrder="stroke"
      style={{ pointerEvents: 'none' }}
    >
      <tspan fontWeight={600}>{truncate(node.name, maxCharacters)}</tspan>
      <tspan x={x} dy={16} fontSize={12} fill={colors.muted}>
        {isSpending && '−'}
        {USDollarNoCents.format(node.value)}
      </tspan>
    </text>
  )
}

NodeLabel.propTypes = {
  node: PropTypes.object.isRequired,
  graph: PropTypes.object.isRequired,
  colors: PropTypes.object.isRequired,
}

function FlowTooltip({ hovered, hub }) {
  if (!hovered) return null

  const { item, x, y } = hovered
  const isLink = item.source !== undefined
  const title = isLink ? `${item.source.name} → ${item.target.name}` : item.name
  const share = hub && hub.value > 0 ? item.value / hub.value : null

  return (
    <div
      role="tooltip"
      style={{
        position: 'absolute',
        left: x,
        top: y,
        transform: 'translate(-50%, calc(-100% - 12px))',
        pointerEvents: 'none',
        whiteSpace: 'nowrap',
        color: 'white',
        background: '#1f2d3d',
        borderRadius: '8px',
        padding: '0.25rem 0.75rem',
        boxShadow:
          '0 0 2px 0 rgba(0, 0, 0, 0.0625), 0 4px 8px 0 rgba(0, 0, 0, 0.125)',
        zIndex: 10,
      }}
    >
      <div style={{ fontWeight: 600 }}>{title}</div>
      <div>
        {USDollar.format(item.value)}
        {share !== null && item !== hub && (
          <span style={{ opacity: 0.7 }}>
            {' '}
            · {(share * 100).toFixed(share < 0.01 ? 1 : 0)}%
          </span>
        )}
      </div>
    </div>
  )
}

FlowTooltip.propTypes = {
  hovered: PropTypes.shape({
    item: PropTypes.object,
    x: PropTypes.number,
    y: PropTypes.number,
  }),
  hub: PropTypes.object,
}

export default function MoneyFlow({ data }) {
  const isDark = useDarkMode()
  const containerRef = useRef(null)
  const width = useWidth(containerRef)
  const gradientPrefix = `money-flow-${useId().replace(/:/g, '')}`
  const [hovered, setHovered] = useState(null)

  const graph = useMemo(
    () => (width > 0 ? layout(data, width) : null),
    [data, width]
  )

  const colors = {
    text: isDark ? '#e0e6ed' : '#1f2d3d',
    muted: '#8492a6',
    surface: isDark ? '#252429' : '#ffffff',
  }

  const hoverAt = item => event => {
    const bounds = containerRef.current.getBoundingClientRect()
    setHovered({
      item,
      x: event.clientX - bounds.left,
      y: event.clientY - bounds.top,
    })
  }

  const isActive = link =>
    !hovered ||
    hovered.item === link ||
    hovered.item === link.source ||
    hovered.item === link.target

  return (
    <div ref={containerRef} style={{ position: 'relative', width: '100%' }}>
      {graph && (
        <svg
          width={width}
          height={graph.height}
          role="img"
          aria-label={`Money flow: ${USDollarNoCents.format(graph.hub?.value ?? 0)} through ${graph.hub?.name}`}
          onMouseLeave={() => setHovered(null)}
        >
          <defs>
            {graph.links.map(link => (
              <linearGradient
                key={link.index}
                id={`${gradientPrefix}-${link.index}`}
                gradientUnits="userSpaceOnUse"
                x1={link.source.x1}
                x2={link.target.x0}
              >
                <stop offset="0%" stopColor={COLORS[link.source.kind]} />
                <stop offset="100%" stopColor={COLORS[link.target.kind]} />
              </linearGradient>
            ))}
          </defs>

          <g fill="none">
            {graph.links.map(link => (
              <g key={link.index}>
                <path
                  d={sankeyLinkHorizontal()(link)}
                  stroke={`url(#${gradientPrefix}-${link.index})`}
                  strokeWidth={Math.max(link.width, 1)}
                  strokeOpacity={
                    hovered?.item === link ? 0.6 : isActive(link) ? 0.35 : 0.1
                  }
                  style={{ transition: 'stroke-opacity 150ms' }}
                />
                {/* Wider invisible stroke so thin ribbons are still easy to hover */}
                <path
                  d={sankeyLinkHorizontal()(link)}
                  stroke="transparent"
                  strokeWidth={Math.max(link.width, 12)}
                  onMouseMove={hoverAt(link)}
                />
              </g>
            ))}
          </g>

          <g>
            {graph.nodes.map(node => (
              <rect
                key={node.index}
                x={node.x0}
                y={node.y0}
                width={node.x1 - node.x0}
                height={Math.max(node.y1 - node.y0, 1)}
                rx={2}
                fill={COLORS[node.kind]}
                onMouseMove={hoverAt(node)}
              />
            ))}
          </g>

          <g>
            {graph.nodes.map(node => (
              <NodeLabel
                key={node.index}
                node={node}
                graph={graph}
                colors={colors}
              />
            ))}
          </g>
        </svg>
      )}

      <FlowTooltip hovered={hovered} hub={graph?.hub} />

      <table className="sr-only">
        <caption>Money flow</caption>
        <thead>
          <tr>
            <th scope="col">From</th>
            <th scope="col">To</th>
            <th scope="col">Amount</th>
          </tr>
        </thead>
        <tbody>
          {data.links.map((link, i) => (
            <tr key={i}>
              <td>{data.nodes[link.source].name}</td>
              <td>{data.nodes[link.target].name}</td>
              <td>{USDollar.format(link.value)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

MoneyFlow.propTypes = {
  data: PropTypes.shape({
    nodes: PropTypes.arrayOf(
      PropTypes.shape({
        name: PropTypes.string,
        kind: PropTypes.oneOf(['income', 'hub', 'group', 'expense', 'balance']),
      })
    ),
    links: PropTypes.arrayOf(
      PropTypes.shape({
        source: PropTypes.number,
        target: PropTypes.number,
        value: PropTypes.number,
      })
    ),
  }).isRequired,
}
