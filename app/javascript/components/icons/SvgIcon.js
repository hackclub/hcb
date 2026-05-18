import React, { useState, useEffect } from 'react'
import PropTypes from 'prop-types'

const cache = {}
const pending = {}

function fetchSvg(src) {
  if (cache[src] || pending[src]) return
  pending[src] = fetch(src)
    .then(r => r.text())
    .then(text => {
      const parser = new DOMParser()
      const doc = parser.parseFromString(text, 'image/svg+xml')
      const svg = doc.querySelector('svg')
      const viewBox = svg?.getAttribute('viewBox') || '0 0 32 32'
      const innerHTML = svg?.innerHTML || ''
      cache[src] = { viewBox, innerHTML }
    })
}

export function preload(...srcs) {
  srcs.forEach(fetchSvg)
}

export default function SvgIcon({ src, size = 16 }) {
  const [svgData, setSvgData] = useState(cache[src] || null)

  useEffect(() => {
    if (cache[src]) {
      setSvgData(cache[src])
      return
    }
    fetchSvg(src)
    pending[src]?.then(() => setSvgData(cache[src]))
  }, [src])

  if (!svgData) {
    return (
      <span style={{ display: 'inline-block', width: size, height: size }} />
    )
  }

  return (
    <svg
      width={size}
      height={size}
      viewBox={svgData.viewBox}
      fill="currentColor"
      xmlns="http://www.w3.org/2000/svg"
      dangerouslySetInnerHTML={{ __html: svgData.innerHTML }}
    />
  )
}

SvgIcon.propTypes = {
  src: PropTypes.string.isRequired,
  size: PropTypes.number,
}
