import { Controller } from '@hotwired/stimulus'
import { select } from 'd3'

export default class extends Controller {
  static values = {
    nodes: Array,
  }

  connect() {
    this.render()
  }

  render() {
    const nodes = this.nodesValue
    if (!nodes.length) return

    const NODE_W = 160,
      NODE_H = 36,
      H_GAP = 60,
      V_GAP = 16,
      PADDING = 24,
      MIN_WIDTH = 800

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

    const leafCount = {}
    function countLeaves(node) {
      const children = childrenOf[node.id]
      leafCount[node.id] =
        children.length === 0
          ? 1
          : children.reduce((s, c) => s + countLeaves(c), 0)
      return leafCount[node.id]
    }
    countLeaves(root)

    // Top-aligned layout: parent sits at the top of its children group
    const yTops = {}
    function assignY(node, top) {
      yTops[node.id] = top
      let cursor = top
      childrenOf[node.id].forEach((child) => {
        assignY(child, cursor)
        cursor += leafCount[child.id] * (NODE_H + V_GAP)
      })
    }
    assignY(root, PADDING)

    const depths = {}
    function assignDepth(node, depth) {
      depths[node.id] = depth
      childrenOf[node.id].forEach((c) => assignDepth(c, depth + 1))
    }
    assignDepth(root, 0)

    const numLeaves = leafCount[root.id]
    const maxDepth = Math.max(...Object.values(depths))
    const calcWidth =
      (maxDepth + 1) * (NODE_W + H_GAP) - H_GAP + 2 * PADDING
    const svgWidth = Math.max(calcWidth, MIN_WIDTH)
    const svgHeight = numLeaves * (NODE_H + V_GAP) - V_GAP + 2 * PADDING

    const actualHGap =
      maxDepth > 0
        ? (svgWidth - 2 * PADDING - (maxDepth + 1) * NODE_W) / maxDepth
        : H_GAP

    select(this.element).selectAll('*').remove()

    const markerId = `arr-${this.element.dataset.subOrganizationsGraphIdParam || Math.random().toString(36).slice(2)}`

    const svg = select(this.element)
      .append('svg')
      .attr('class', 'hcb-suborg-graph')
      .attr('viewBox', `0 0 ${svgWidth} ${svgHeight}`)
      .style('display', 'block')
      .style('width', '100%')
      .style('height', 'auto')

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

    // Edges drawn first so they appear behind nodes
    nodes.forEach((node) => {
      const children = childrenOf[node.id]
      if (!children.length) return

      const ex = PADDING + depths[node.id] * (NODE_W + actualHGap) + NODE_W
      const ey = yTops[node.id] + NODE_H / 2

      children.forEach((child) => {
        const cx2 = PADDING + depths[child.id] * (NODE_W + actualHGap)
        const cy2 = yTops[child.id] + NODE_H / 2

        svg
          .append('line')
          .attr('class', 'edge')
          .attr('x1', ex)
          .attr('y1', ey)
          .attr('x2', cx2)
          .attr('y2', cy2)
          .attr('stroke-width', 1.5)
          .attr('marker-end', `url(#${markerId})`)
      })
    })

    nodes.forEach((node) => {
      const x = PADDING + depths[node.id] * (NODE_W + actualHGap)
      const y = yTops[node.id]
      const isRoot = node.isRoot
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
    })
  }
}
