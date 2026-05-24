import { Controller } from '@hotwired/stimulus'
import { select } from 'd3-selection'

const NODE_W = 160
const NODE_H = 36
const MIN_H_GAP = 60
const V_GAP = 16
const PADDING = 24
const MAX_VISIBLE = 14

export default class extends Controller {
  static values = { nodes: Array }

  connect() {
    this.render()
  }

  render() {
    const nodes = this.nodesValue
    if (!nodes.length) return

    const allIds = new Set(nodes.map((n) => n.id))
    const childrenOf = Object.fromEntries(nodes.map((n) => [n.id, []]))
    nodes.forEach((n) => {
      if (n.parentId !== null && allIds.has(n.parentId)) {
        childrenOf[n.parentId].push(n)
      }
    })
    Object.values(childrenOf).forEach((arr) =>
      arr.sort((a, b) => a.name.localeCompare(b.name)),
    )

    const root = nodes.find((n) => n.isRoot)
    if (!root) return

    const containerWidth = Math.max(this.element.clientWidth || 800, 600)
    select(this.element).selectAll('*').remove()

    const markerId = `arr-${Math.random().toString(36).slice(2)}`
    const directChildren = childrenOf[root.id]
    const isFlat =
      nodes.length > 1 &&
      directChildren.every((c) => childrenOf[c.id].length === 0)

    if (isFlat && directChildren.length > MAX_VISIBLE) {
      this.renderWithMore(root, directChildren, containerWidth, markerId)
    } else {
      this.renderTree(nodes, root, childrenOf, containerWidth, markerId)
    }
  }

  // Collapsed view: first MAX_VISIBLE nodes + dashed "+N more" that opens a modal
  renderWithMore(root, allChildren, containerWidth, markerId) {
    const visible = allChildren.slice(0, MAX_VISIBLE)
    const hiddenCount = allChildren.length - visible.length
    const numRows = MAX_VISIBLE + 1

    const svgWidth = containerWidth
    const svgHeight = numRows * (NODE_H + V_GAP) - V_GAP + 2 * PADDING
    const hGap = svgWidth - 2 * PADDING - 2 * NODE_W
    const childX = PADDING + NODE_W + hGap
    const rowY = (i) => PADDING + i * (NODE_H + V_GAP)

    const svg = this.createSvg(svgWidth, svgHeight, markerId)

    ;[...visible, null].forEach((_, i) => {
      svg
        .append('line')
        .attr('class', 'edge')
        .attr('x1', PADDING + NODE_W)
        .attr('y1', PADDING + NODE_H / 2)
        .attr('x2', childX)
        .attr('y2', rowY(i) + NODE_H / 2)
        .attr('stroke-width', 1.5)
        .attr('marker-end', `url(#${markerId})`)
    })

    this.drawNode(svg, root, PADDING, PADDING, true)
    visible.forEach((child, i) => this.drawNode(svg, child, childX, rowY(i), false))

    const moreY = rowY(MAX_VISIBLE)
    const g = svg
      .append('g')
      .style('cursor', 'pointer')
      .on('click', () => this.openModal())
    g.append('rect')
      .attr('class', 'more-rect')
      .attr('x', childX)
      .attr('y', moreY)
      .attr('width', NODE_W)
      .attr('height', NODE_H)
      .attr('rx', 6)
      .attr('stroke-width', 2)
    g.append('text')
      .attr('class', 'more-text')
      .attr('x', childX + NODE_W / 2)
      .attr('y', moreY + NODE_H / 2)
      .attr('text-anchor', 'middle')
      .attr('dominant-baseline', 'central')
      .text(`+${hiddenCount} more`)
  }

  openModal() {
    document.getElementById('sub-org-graph-more-trigger')?.click()
  }

  // Tree layout for all other cases
  renderTree(nodes, root, childrenOf, containerWidth, markerId) {
    const leafCount = {}
    const countLeaves = (node) => {
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
      childrenOf[node.id].forEach((child) => {
        assignY(child, cursor)
        cursor += leafCount[child.id] * (NODE_H + V_GAP)
      })
    }
    assignY(root, PADDING)

    const depths = {}
    const assignDepth = (node, depth) => {
      depths[node.id] = depth
      childrenOf[node.id].forEach((c) => assignDepth(c, depth + 1))
    }
    assignDepth(root, 0)

    const maxDepth =
      Object.values(depths).length > 0
        ? Math.max(...Object.values(depths))
        : 0
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

    nodes.forEach((node) => {
      const children = childrenOf[node.id]
      if (!children.length) return
      const ex = PADDING + depths[node.id] * (NODE_W + hGap) + NODE_W
      const ey = yTops[node.id] + NODE_H / 2
      children.forEach((child) => {
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

    nodes.forEach((node) =>
      this.drawNode(
        svg,
        node,
        PADDING + depths[node.id] * (NODE_W + hGap),
        yTops[node.id],
        node.isRoot,
      ),
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
    const label =
      node.name.length > 21 ? node.name.slice(0, 20) + '…' : node.name
    const a = svg.append('a').attr('href', node.href).attr('title', node.name)
    a.append('rect')
      .attr('class', isRoot ? 'root-rect' : 'node-rect')
      .attr('x', x)
      .attr('y', y)
      .attr('width', NODE_W)
      .attr('height', NODE_H)
      .attr('rx', isRoot ? 18 : 6)
      .attr('stroke-width', 2)
    a.append('text')
      .attr('class', isRoot ? 'root-text' : 'node-text')
      .attr('x', x + NODE_W / 2)
      .attr('y', y + NODE_H / 2)
      .attr('text-anchor', 'middle')
      .attr('dominant-baseline', 'central')
      .text(label)
  }


}
