import { Controller } from '@hotwired/stimulus'
import { stratify } from 'd3-hierarchy'
import { tree } from 'd3-hierarchy'
import { select } from 'd3-selection'
import { zoom } from 'd3-zoom'
import { linkHorizontal } from 'd3-shape'

export default class extends Controller {
  static values = { nodes: Array, root: Number }

  connect() {
    const dark = document.documentElement.dataset.dark === 'true'
    const nodes = this.nodesValue
    const rootId = String(this.rootValue)

    const hierarchy = stratify()
      .id(d => String(d.id))
      .parentId(d => (d.parent_id ? String(d.parent_id) : null))(nodes)

    const nodeW = 160
    const nodeH = 36
    const hGap = 60
    const vGap = 14

    const treeLayout = tree().nodeSize([nodeH + vGap, nodeW + hGap])
    treeLayout(hierarchy)

    let minX = Infinity
    let maxX = -Infinity
    hierarchy.each(d => {
      if (d.x < minX) minX = d.x
      if (d.x > maxX) maxX = d.x
    })

    const svgHeight = Math.max(maxX - minX + nodeH * 2 + 48, 300)

    const svg = select(this.element)
      .append('svg')
      .attr('width', '100%')
      .attr('height', svgHeight)
      .style('display', 'block')

    const g = svg
      .append('g')
      .attr('transform', `translate(${nodeW / 2 + 24},${-minX + nodeH})`)

    const linkGen = linkHorizontal()
      .x(d => d.y)
      .y(d => d.x)

    g.append('g')
      .selectAll('path')
      .data(hierarchy.links())
      .join('path')
      .attr('fill', 'none')
      .attr('stroke', dark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.15)')
      .attr('stroke-width', 1.5)
      .attr('d', linkGen)

    const node = g
      .append('g')
      .selectAll('g')
      .data(hierarchy.descendants())
      .join('g')
      .attr('transform', d => `translate(${d.y},${d.x})`)
      .style('cursor', 'pointer')
      .on('click', (_, d) => {
        window.location = d.data.href
      })

    node
      .append('rect')
      .attr('x', -nodeW / 2)
      .attr('y', -nodeH / 2)
      .attr('width', nodeW)
      .attr('height', nodeH)
      .attr('rx', d => (String(d.data.id) === rootId ? 18 : 6))
      .attr('fill', d => {
        if (String(d.data.id) === rootId) return '#ec3750'
        return dark ? '#2a2a2f' : '#fff'
      })
      .attr('stroke', d => {
        if (String(d.data.id) === rootId) return '#c0392b'
        return dark ? '#444' : '#ddd'
      })
      .attr('stroke-width', 1.5)

    node
      .append('text')
      .attr('text-anchor', 'middle')
      .attr('dominant-baseline', 'central')
      .attr('font-size', 13)
      .attr('font-family', 'system-ui, -apple-system, sans-serif')
      .attr('fill', d =>
        String(d.data.id) === rootId ? '#fff' : dark ? '#fff' : '#000'
      )
      .text(d =>
        d.data.name.length > 21 ? d.data.name.slice(0, 20) + '…' : d.data.name
      )

    svg.call(
      zoom().on('zoom', e => g.attr('transform', e.transform))
    )
  }

  disconnect() {
    select(this.element).select('svg').remove()
  }
}
