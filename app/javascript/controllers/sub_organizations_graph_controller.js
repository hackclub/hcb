import { Controller } from '@hotwired/stimulus'
import { select } from 'd3-selection'

const NODE_W = 200
const NODE_H = 56
const ROOT_H = 40
// Distance from a node down to the box holding its children, and the gaps
// between cards inside that box.
const LEVEL_GAP = 36
const ROW_GAP = 22
const SIBLING_GAP = 16
const PADDING = 24
// Breathing room inside the box around a node's children, and the gap between
// the card grid and each opened branch below it.
const GROUP_PAD = 16
const SECTION_GAP = 24
// The "+3" pill straddling the bottom edge of a node that has children.
const TOGGLE_W = 42
const TOGGLE_H = 20
// Connectors are drawn as hairline rects rather than paths so their geometry
// can be transitioned in CSS. Keep in step with $motion in the stylesheet.
const EDGE_W = 1.5
const MOTION_MS = 280
const MAX_COLLAPSED_HEIGHT = 420

const FONT_NODE = '600 13px system-ui, -apple-system, sans-serif'
const FONT_ROOT = '600 14px system-ui, -apple-system, sans-serif'

let measureCtx = null
const widthCache = new Map()

// Real text measurement, so labels are only truncated when they actually don't
// fit rather than at a fixed character count.
function textWidth(text, font) {
  const key = `${font}|${text}`
  if (widthCache.has(key)) return widthCache.get(key)
  if (!measureCtx)
    measureCtx = document.createElement('canvas').getContext('2d')
  measureCtx.font = font
  const w = measureCtx.measureText(text).width
  widthCache.set(key, w)
  return w
}

function truncateToWidth(text, font, maxWidth) {
  if (textWidth(text, font) <= maxWidth) return text
  let lo = 0
  let hi = text.length
  while (lo < hi) {
    const mid = Math.ceil((lo + hi) / 2)
    if (textWidth(text.slice(0, mid) + '…', font) <= maxWidth) lo = mid
    else hi = mid - 1
  }
  return text.slice(0, lo) + '…'
}

export default class extends Controller {
  static values = {
    nodes: Array,
    src: String,
  }

  connect() {
    // Whatever is open is always a single path down from the root, so at most
    // one branch is unfolded at a time. See #toggle.
    this.expanded = new Set()
    this.heightExpanded = false
    this.render()

    // The layout wraps to the available width, so it has to be recomputed when
    // that width changes (including the first time it settles after paint).
    this.onResize = () => {
      if (this.resizeTimer) clearTimeout(this.resizeTimer)
      this.resizeTimer = setTimeout(() => {
        if (Math.abs((this.element.clientWidth || 0) - this.lastWidth) > 8)
          this.render()
      }, 150)
    }
    if (typeof ResizeObserver === 'undefined') {
      window.addEventListener('resize', this.onResize)
    } else {
      this.resizeObserver = new ResizeObserver(this.onResize)
      this.resizeObserver.observe(this.element)
    }

    if (this.hasSrcValue) {
      fetch(this.srcValue, { headers: { Accept: 'application/json' } })
        .then(r => r.json())
        .then(data => {
          const lookup = Object.fromEntries(data.map(d => [d.id, d]))
          this.nodesValue = this.nodesValue.map(n => ({
            ...n,
            ...(lookup[n.id] || {}),
          }))
          this.render()
        })
    }
  }

  disconnect() {
    if (this.resizeTimer) clearTimeout(this.resizeTimer)
    if (this.resizeObserver) this.resizeObserver.disconnect()
    window.removeEventListener('resize', this.onResize)
  }

  buildChildrenOf(nodes) {
    const allIds = new Set(nodes.map(n => n.id))
    const childrenOf = Object.fromEntries(nodes.map(n => [n.id, []]))
    nodes.forEach(n => {
      if (n.parentId !== null && allIds.has(n.parentId))
        childrenOf[n.parentId].push(n)
    })
    Object.values(childrenOf).forEach(arr =>
      arr.sort((a, b) => a.name.localeCompare(b.name))
    )
    return childrenOf
  }

  // Opening a node opens the whole path down to it and nothing else, so a
  // branch can be followed to its end while everything beside it stays folded
  // away. Closing a node leaves the path above it open, which puts you back
  // where you were rather than at the top.
  toggle(id) {
    const path = []
    for (
      let node = this.nodeById[id];
      node && !node.isRoot;
      node = this.nodeById[node.parentId]
    )
      path.push(node.id)

    const wasOpen = this.expanded.has(id)
    this.expanded = new Set(wasOpen ? path.slice(1) : path)
    // Expanding shouldn't reveal nodes into a clipped area.
    if (!wasOpen) this.heightExpanded = true
    this.render()
  }

  render() {
    const nodes = this.nodesValue
    if (!nodes.length) return

    const root = nodes.find(n => n.isRoot)
    if (!root) return

    this.nodeById = Object.fromEntries(nodes.map(n => [n.id, n]))
    const childrenOf = this.buildChildrenOf(nodes)
    // The root is always open; every other branch is drawn only once someone
    // asks for it.
    const shownChildrenOf = Object.fromEntries(
      Object.entries(childrenOf).map(([id, children]) => [
        id,
        this.expanded.has(Number(id)) || Number(id) === root.id ? children : [],
      ])
    )

    const containerWidth = this.element.clientWidth || 800
    this.lastWidth = containerWidth

    const svgHeight = this.renderTree(
      root,
      shownChildrenOf,
      childrenOf,
      containerWidth
    )
    this.applyHeightToggle(svgHeight)
  }

  // Clips the graph to MAX_COLLAPSED_HEIGHT and renders a "Show more" toggle
  // when it is taller than that, so the UI below stays reachable on load.
  applyHeightToggle(svgHeight) {
    const clipped = svgHeight > MAX_COLLAPSED_HEIGHT && !this.heightExpanded
    this.graphContainer.style.maxHeight = clipped
      ? `${MAX_COLLAPSED_HEIGHT}px`
      : ''
    this.graphContainer.style.overflowY = clipped ? 'hidden' : ''

    if (!clipped) {
      if (this.showMore) this.showMore.remove()
      this.showMore = null
      return
    }
    if (this.showMore) return

    this.showMore = document.createElement('button')
    this.showMore.type = 'button'
    this.showMore.className = 'suborg-graph-toggle'
    this.showMore.textContent = 'Show more'
    this.showMore.addEventListener('click', () => {
      this.heightExpanded = true
      this.render()
    })
    this.element.appendChild(this.showMore)
  }

  // A node's children live in a box directly beneath it, joined by a single
  // line. Membership is shown by containment, which is why the cards inside
  // need no lines of their own.
  //
  // Inside the box, children that are closed sit in a plain grid of cards.
  // Children that are open can't — they carry a box of their own — so each is
  // stacked full width below the grid as its own section. Reading order stays
  // alphabetical: closed cards first, then the opened branches.
  measure(node, shownChildrenOf, childrenOf, maxWidth) {
    const selfW = this.nodeWidth(node, maxWidth)
    const selfH = node.isRoot ? ROOT_H : NODE_H
    const childCount = (childrenOf[node.id] || []).length
    const children = shownChildrenOf[node.id] || []

    const block = { node, selfW, selfH, childCount, cards: [], sections: [] }
    if (!children.length) return Object.assign(block, { w: selfW, h: selfH })

    // A lone child needs no box around it — a line straight down reads better,
    // and it keeps long single-child chains from nesting box inside box.
    const boxed = children.length > 1
    const pad = boxed ? GROUP_PAD : 0
    const inner = Math.max(NODE_W, maxWidth - pad * 2)

    const isOpen = c => (shownChildrenOf[c.id] || []).length > 0
    const measureChild = c =>
      this.measure(c, shownChildrenOf, childrenOf, inner)

    block.cards = children.filter(c => !isOpen(c)).map(measureChild)
    block.sections = children.filter(isOpen).map(measureChild)

    // The grid takes as many columns as the available width allows. It depends
    // on width alone, so opening a branch never reshuffles the cards around it.
    const perRow = Math.max(
      1,
      Math.floor((inner + SIBLING_GAP) / (NODE_W + SIBLING_GAP))
    )
    block.cols = Math.min(perRow, block.cards.length)
    const rows = block.cols ? Math.ceil(block.cards.length / block.cols) : 0
    block.gridW = block.cols
      ? block.cols * NODE_W + (block.cols - 1) * SIBLING_GAP
      : 0
    block.gridH = rows ? rows * NODE_H + (rows - 1) * ROW_GAP : 0

    const sectionsW = block.sections.length
      ? Math.max(...block.sections.map(s => s.w))
      : 0
    const sectionsH =
      block.sections.reduce((sum, s) => sum + s.h, 0) +
      SECTION_GAP * Math.max(0, block.sections.length - 1)

    block.boxed = boxed
    block.contentW = Math.max(block.gridW, sectionsW)
    block.contentH =
      block.gridH + (block.gridH && sectionsH ? SECTION_GAP : 0) + sectionsH

    return Object.assign(block, {
      w: Math.max(selfW, block.contentW + pad * 2),
      h: selfH + LEVEL_GAP + block.contentH + pad * 2,
    })
  }

  // Turns the measured tree into absolute positions. Everything is centred on
  // the same axis as its parent, so every connector is a short straight drop.
  place(block, left, top, out) {
    block.x = left + (block.w - block.selfW) / 2
    block.y = top
    out.nodes.push(block)

    if (!block.cards.length && !block.sections.length) return

    const pad = block.boxed ? GROUP_PAD : 0
    const contentLeft = left + (block.w - block.contentW) / 2
    const contentTop = top + block.selfH + LEVEL_GAP + pad

    // Keyed by the node they belong to, so that across renders each box and
    // connector keeps its element and animates to its new size and place.
    if (block.boxed) {
      out.groups.push({
        key: block.node.id,
        x: contentLeft - pad,
        y: contentTop - pad,
        w: block.contentW + pad * 2,
        h: block.contentH + pad * 2,
      })
    }

    // One line, from under the toggle pill into the box (or straight into the
    // single child when there is no box).
    const cx = block.x + block.selfW / 2
    const lineTop = top + block.selfH + TOGGLE_H / 2
    out.edges.push({
      key: block.node.id,
      x: cx - EDGE_W / 2,
      y: lineTop,
      h: contentTop - pad - lineTop,
    })

    const gridLeft = contentLeft + (block.contentW - block.gridW) / 2
    block.cards.forEach((card, i) => {
      const col = i % block.cols
      const row = Math.floor(i / block.cols)
      this.place(
        card,
        gridLeft + col * (NODE_W + SIBLING_GAP),
        contentTop + row * (NODE_H + ROW_GAP),
        out
      )
    })

    let y = contentTop + block.gridH
    block.sections.forEach(section => {
      if (y > contentTop) y += SECTION_GAP
      this.place(
        section,
        contentLeft + (block.contentW - section.w) / 2,
        y,
        out
      )
      y += section.h
    })
  }

  nodeWidth(node, maxWidth) {
    if (node.isRoot) {
      // The root pill sizes to its label so org names aren't needlessly cut.
      return Math.min(
        Math.max(NODE_W, Math.ceil(textWidth(node.name, FONT_ROOT)) + 40),
        maxWidth
      )
    }
    return Math.min(NODE_W, maxWidth)
  }

  renderTree(root, shownChildrenOf, childrenOf, containerWidth) {
    const maxWidth = Math.max(NODE_W, containerWidth - PADDING * 2)
    const tree = this.measure(root, shownChildrenOf, childrenOf, maxWidth)

    const svgWidth = Math.max(tree.w + PADDING * 2, containerWidth)
    const svgHeight = tree.h + PADDING * 2 + TOGGLE_H / 2
    const out = { nodes: [], edges: [], groups: [] }
    this.place(tree, (svgWidth - tree.w) / 2, PADDING, out)

    const svg = this.ensureSvg()
    svg.attr('width', svgWidth).attr('height', svgHeight)

    this.joinRects(this.layers.groups, 'group-rect', out.groups, sel =>
      sel
        .attr('x', d => d.x)
        .attr('y', d => d.y)
        .attr('width', d => d.w)
        .attr('height', d => d.h)
        .attr('rx', 12)
    )

    this.joinRects(this.layers.edges, 'edge-line', out.edges, sel =>
      sel
        .attr('x', d => d.x)
        .attr('y', d => d.y)
        .attr('width', EDGE_W)
        .attr('height', d => d.h)
    )

    this.joinNodes(out.nodes)

    return svgHeight
  }

  // The svg and its three layers outlive a render; only their contents change.
  // Keeping the elements around is what lets a card slide to its new place
  // instead of vanishing and reappearing there.
  ensureSvg() {
    if (this.svg && this.element.contains(this.svg.node())) return this.svg

    select(this.element).selectAll('*').remove()
    this.showMore = null
    this.graphContainer = select(this.element).append('div').node()
    this.svg = select(this.graphContainer)
      .append('svg')
      .attr('class', 'hcb-suborg-graph')
      .style('display', 'block')
    this.layers = {
      groups: this.svg.append('g'),
      edges: this.svg.append('g'),
      nodes: this.svg.append('g'),
    }
    return this.svg
  }

  joinRects(layer, className, data, apply) {
    const existing = layer.selectAll(`rect.${className}`).data(data, d => d.key)
    this.retire(existing.exit())

    const entering = existing
      .enter()
      .append('rect')
      .attr('class', `${className} is-entering`)
    apply(entering.merge(existing))
    this.reveal(entering)
  }

  joinNodes(blocks) {
    const existing = this.layers.nodes
      .selectAll('g.suborg-node')
      .data(blocks, d => d.node.id)
    this.retire(existing.exit())

    const entering = existing
      .enter()
      .append('g')
      .attr('class', 'suborg-node is-entering')

    entering
      .merge(existing)
      .attr('transform', d => `translate(${d.x},${d.y})`)
      .each((block, i, group) => this.paintNode(select(group[i]), block))
    this.reveal(entering)
  }

  // Entering elements start transparent and are faded in on the next frame, so
  // the transition has a value to move from.
  reveal(selection) {
    const elements = selection.nodes()
    if (elements.length)
      requestAnimationFrame(() =>
        elements.forEach(el => el.classList.remove('is-entering'))
      )
  }

  // Leaving elements fade out where they stand and are dropped afterwards.
  retire(selection) {
    const elements = selection.nodes()
    if (!elements.length) return

    selection.classed('is-leaving', true).style('pointer-events', 'none')
    setTimeout(() => elements.forEach(el => el.remove()), MOTION_MS)
  }

  // Contents are redrawn in the node's own coordinates each render; the group
  // element itself persists, and its transform is what animates.
  paintNode(g, block) {
    g.selectAll('*').remove()

    const { node, selfW, selfH, childCount } = block
    const isRoot = !!node.isRoot

    const a = g.append('a').attr('href', node.href)
    a.append('title').text(node.name)
    a.append('rect')
      .attr('class', isRoot ? 'root-rect' : 'node-rect')
      .attr('width', selfW)
      .attr('height', selfH)
      .attr('rx', isRoot ? ROOT_H / 2 : 8)
      .attr('stroke-width', isRoot ? 0 : 1)

    if (isRoot) {
      a.append('text')
        .attr('class', 'root-text')
        .attr('x', selfW / 2)
        .attr('y', ROOT_H / 2)
        .attr('text-anchor', 'middle')
        .attr('dominant-baseline', 'central')
        .text(truncateToWidth(node.name, FONT_ROOT, selfW - 32))
      return
    }

    a.append('text')
      .attr('class', 'node-text')
      .attr('x', 12)
      .attr('y', 20)
      .attr('dominant-baseline', 'middle')
      .text(truncateToWidth(node.name, FONT_NODE, selfW - 24))

    a.append('text')
      .attr('class', 'node-meta')
      .attr('x', 12)
      .attr('y', 40)
      .attr('dominant-baseline', 'middle')
      .text(
        node.balance_cents == null
          ? '$ —'
          : this.formatBalance(node.balance_cents)
      )

    a.append('text')
      .attr('class', 'node-meta')
      .attr('x', selfW - 12)
      .attr('y', 40)
      .attr('text-anchor', 'end')
      .attr('dominant-baseline', 'middle')
      .text(node.card_count == null ? '💳 —' : `💳 ${node.card_count}`)

    if (childCount > 0) this.paintToggle(g, block)
  }

  // A pill on the node's bottom edge: how many sub-organizations are inside,
  // and the control that opens them.
  paintToggle(g, block) {
    const open = this.expanded.has(block.node.id)
    const cx = block.selfW / 2
    const cy = block.selfH

    const toggle = g
      .append('g')
      .attr('class', `node-toggle ${open ? 'is-open' : ''}`)
      .style('cursor', 'pointer')
      .on('click', () => this.toggle(block.node.id))
    toggle
      .append('title')
      .text(
        open
          ? 'Hide sub-organizations'
          : `Show ${block.childCount} sub-organization${block.childCount === 1 ? '' : 's'}`
      )
    toggle
      .append('rect')
      .attr('class', 'toggle-rect')
      .attr('x', cx - TOGGLE_W / 2)
      .attr('y', cy - TOGGLE_H / 2)
      .attr('width', TOGGLE_W)
      .attr('height', TOGGLE_H)
      .attr('rx', TOGGLE_H / 2)
      .attr('stroke-width', 1)
    toggle
      .append('text')
      .attr('class', 'toggle-text')
      .attr('x', cx)
      .attr('y', cy)
      .attr('text-anchor', 'middle')
      .attr('dominant-baseline', 'central')
      .text(open ? `− ${block.childCount}` : `+ ${block.childCount}`)
  }

  formatBalance(cents) {
    const dollars = (cents || 0) / 100
    const abs = Math.abs(dollars)
    const formatted = abs.toLocaleString('en-US', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    })
    return (dollars < 0 ? '-$' : '$') + formatted
  }
}
