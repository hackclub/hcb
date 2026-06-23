import { Controller } from '@hotwired/stimulus'
import { select } from 'd3-selection'

const NODE_W = 210
const NODE_H = 50
const ROOT_H = 36
const MIN_H_GAP = 60
const V_GAP = 8
const PADDING = 24
// Any node with more than this many children is collapsed behind a
// "+N organizations" node until the viewer expands it. This keeps the graph
// short so the existing UI (search bar, list) stays reachable on page load.
const COLLAPSE_THRESHOLD = 4

export default class extends Controller {
  static values = {
    nodes: Array,
    src: String,
  }

  connect() {
    this.expandedNodes = new Set()
    this.render()
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

  // Replaces children beyond the threshold with a single synthetic "+N more"
  // node (unless the parent has been expanded). Children that have sub-nodes of
  // their own are never collapsed — only leaf children are folded away, so we
  // never hide an entire branch behind a "+N" node. Synthetic nodes get an
  // empty children list so traversal stops at them.
  buildDisplayChildren(childrenOf) {
    const display = {}
    Object.entries(childrenOf).forEach(([id, children]) => {
      const leaves = children.filter(c => (childrenOf[c.id] || []).length === 0)

      if (
        children.length > COLLAPSE_THRESHOLD &&
        leaves.length > 0 &&
        !this.expandedNodes.has(id)
      ) {
        const parents = children.filter(
          c => (childrenOf[c.id] || []).length > 0
        )
        // Keep every parent child visible; fill any remaining slots up to the
        // threshold with leaf children, and collapse the rest.
        const slots = Math.max(0, COLLAPSE_THRESHOLD - parents.length)
        const visibleLeaves = leaves.slice(0, slots)
        const hiddenCount = leaves.length - visibleLeaves.length

        if (hiddenCount > 0) {
          const visibleIds = new Set(
            [...parents, ...visibleLeaves].map(c => c.id)
          )
          const moreNode = {
            id: `more:${id}`,
            isMore: true,
            parentNodeId: id,
            hiddenCount,
          }
          // Preserve the original (alphabetical) ordering among visible nodes.
          display[id] = [
            ...children.filter(c => visibleIds.has(c.id)),
            moreNode,
          ]
          display[moreNode.id] = []
          return
        }
      }

      display[id] = children
    })
    return display
  }

  render() {
    const nodes = this.nodesValue
    if (!nodes.length) return

    const childrenOf = this.buildChildrenOf(nodes)
    const root = nodes.find(n => n.isRoot)
    if (!root) return

    const displayChildren = this.buildDisplayChildren(childrenOf)

    // Flatten the displayed tree (real + synthetic nodes) by walking from root.
    const displayNodes = []
    const lookup = Object.fromEntries(nodes.map(n => [n.id, n]))
    const walk = id => {
      const node = lookup[id]
      if (node) displayNodes.push(node)
      ;(displayChildren[id] || []).forEach(child => {
        if (child.isMore) displayNodes.push(child)
        walk(child.id)
      })
    }
    walk(root.id)

    const containerWidth = Math.max(this.element.clientWidth || 800, 600)
    select(this.element).selectAll('*').remove()

    const markerId = `arr-${Math.random().toString(36).slice(2)}`
    this.renderTree(
      displayNodes,
      root,
      displayChildren,
      containerWidth,
      markerId
    )
  }

  createSvg(width, height, markerId) {
    const svg = select(this.element)
      .append('svg')
      .attr('class', 'hcb-suborg-graph')
      .attr('width', width)
      .attr('height', height)
      .style('display', 'block')

    svg
      .append('defs')
      .append('marker')
      .attr('id', markerId)
      .attr('markerWidth', 8)
      .attr('markerHeight', 6)
      .attr('refX', 8)
      .attr('refY', 3)
      .attr('orient', 'auto')
      .append('polygon')
      .attr('class', 'arrow-head')
      .attr('points', '0 0,8 3,0 6')

    return svg
  }

  drawNode(svg, node, x, y, isRoot) {
    if (node.isMore) {
      this.drawMoreNode(svg, node, x, y)
      return
    }

    const h = isRoot ? ROOT_H : NODE_H
    const maxChars = 28
    const label =
      node.name.length > maxChars
        ? node.name.slice(0, maxChars - 1) + '…'
        : node.name
    const a = svg.append('a').attr('href', node.href).attr('title', node.name)
    a.append('rect')
      .attr('class', isRoot ? 'root-rect' : 'node-rect')
      .attr('x', x)
      .attr('y', y)
      .attr('width', NODE_W)
      .attr('height', h)
      .attr('rx', isRoot ? ROOT_H / 2 : 6)
      .attr('stroke-width', 2)

    if (isRoot) {
      a.append('text')
        .attr('class', 'root-text')
        .attr('x', x + NODE_W / 2)
        .attr('y', y + ROOT_H / 2)
        .attr('text-anchor', 'middle')
        .attr('dominant-baseline', 'central')
        .text(label)
      return
    }

    a.append('text')
      .attr('class', 'node-text')
      .attr('x', x + 12)
      .attr('y', y + 14)
      .attr('dominant-baseline', 'middle')
      .text(label)

    a.append('text')
      .attr('class', 'node-meta')
      .attr('x', x + 12)
      .attr('y', y + 35)
      .attr('dominant-baseline', 'middle')
      .text(
        node.balance_cents == null
          ? '$ —'
          : this.formatBalance(node.balance_cents)
      )

    a.append('text')
      .attr('class', 'node-meta')
      .attr('x', x + NODE_W - 12)
      .attr('y', y + 35)
      .attr('text-anchor', 'end')
      .attr('dominant-baseline', 'middle')
      .text(node.card_count == null ? '💳 —' : `💳 ${node.card_count}`)
  }

  drawMoreNode(svg, node, x, y) {
    const moreG = svg
      .append('g')
      .attr('class', 'more-node')
      .style('cursor', 'pointer')
      .on('click', () => {
        this.expandedNodes.add(node.parentNodeId)
        this.render()
      })
    moreG
      .append('rect')
      .attr('class', 'more-rect')
      .attr('x', x)
      .attr('y', y)
      .attr('width', NODE_W)
      .attr('height', NODE_H)
      .attr('rx', 6)
      .attr('stroke-width', 2)
    const label =
      node.hiddenCount === 1
        ? '+1 organization'
        : `+${node.hiddenCount} organizations`
    moreG
      .append('text')
      .attr('class', 'more-text')
      .attr('x', x + NODE_W / 2)
      .attr('y', y + NODE_H / 2)
      .attr('text-anchor', 'middle')
      .attr('dominant-baseline', 'central')
      .text(label)
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

  // Tree layout for nested hierarchies (and flat lists)
  renderTree(nodes, root, childrenOf, containerWidth, markerId) {
    const leafCount = {}
    const countLeaves = node => {
      const children = childrenOf[node.id]
      leafCount[node.id] =
        children.length === 0
          ? 1
          : children.reduce((s, c) => s + countLeaves(c), 0)
      return leafCount[node.id]
    }
    countLeaves(root)

    const yTops = {}
    const assignY = (node, top) => {
      yTops[node.id] = top
      let cursor = top
      childrenOf[node.id].forEach(child => {
        assignY(child, cursor)
        cursor += leafCount[child.id] * (NODE_H + V_GAP)
      })
    }
    assignY(root, PADDING)

    const depths = {}
    const assignDepth = (node, depth) => {
      depths[node.id] = depth
      childrenOf[node.id].forEach(c => assignDepth(c, depth + 1))
    }
    assignDepth(root, 0)

    const maxDepth =
      Object.values(depths).length > 0 ? Math.max(...Object.values(depths)) : 0
    const minWidth =
      (maxDepth + 1) * (NODE_W + MIN_H_GAP) - MIN_H_GAP + 2 * PADDING
    const svgWidth = Math.max(minWidth, containerWidth)
    const svgHeight =
      leafCount[root.id] * (NODE_H + V_GAP) - V_GAP + 2 * PADDING
    const hGap =
      maxDepth > 0
        ? (svgWidth - 2 * PADDING - (maxDepth + 1) * NODE_W) / maxDepth
        : MIN_H_GAP

    const svg = this.createSvg(svgWidth, svgHeight, markerId)

    nodes.forEach(node => {
      const children = childrenOf[node.id]
      if (!children.length) return
      const ex = PADDING + depths[node.id] * (NODE_W + hGap) + NODE_W
      const ey = yTops[node.id] + (node.isRoot ? ROOT_H : NODE_H) / 2
      children.forEach(child => {
        svg
          .append('line')
          .attr('class', 'edge')
          .attr('x1', ex)
          .attr('y1', ey)
          .attr('x2', PADDING + depths[child.id] * (NODE_W + hGap))
          .attr('y2', yTops[child.id] + NODE_H / 2)
          .attr('stroke-width', 1.5)
          .attr('marker-end', `url(#${markerId})`)
      })
    })

    nodes.forEach(node =>
      this.drawNode(
        svg,
        node,
        PADDING + depths[node.id] * (NODE_W + hGap),
        yTops[node.id],
        node.isRoot
      )
    )
  }
}
