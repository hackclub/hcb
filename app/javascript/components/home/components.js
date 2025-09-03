import React from 'react'
import PropTypes from 'prop-types'
import { USDollar } from './utils'

export const renderLegend = ({ payload }) => {
  return (
    <>
      <div className="category_chart">
        {payload.slice(0, 10).map((entry, index) => (
          <span
            key={`item-${index}`}
            style={{
              color: entry.color,
              fontWeight: 400,
              textWrap: 'none',
              marginRight: '16px',
            }}
          >
            <wbr />●{'\u00A0'}
            {entry.payload.truncated}
          </span>
        ))}
      </div>
      {payload.length > 10 && (
        <div style={{ textAlign: 'center' }} className="muted mt1">
          And {payload.length - 7} additional categories...
        </div>
      )}
      <style>
        {`
        .category_chart {
          text-align: center;
          text-wrap: balance!important;
          white-space: normal;
        }
        `}
      </style>
    </>
  )
}

export const CustomTooltip = ({ active, payload }) => {
  if (active && payload && payload.length) {
    return (
      <div
        style={{
          color: 'white',
          background: '#1f2d3d',
          borderRadius: '8px',
          padding: '0.25rem 0.75rem',
          boxShadow:
            '0 0 2px 0 rgba(0, 0, 0, 0.0625), 0 4px 8px 0 rgba(0, 0, 0, 0.125)',
        }}
      >
        {payload[0].payload.name} {payload[0].payload.name && <br />}
        {USDollar.format(payload[0].value)}
      </div>
    )
  }
  return null
}

CustomTooltip.propTypes = {
  active: PropTypes.bool,
  payload: PropTypes.arrayOf(
    PropTypes.shape({
      payload: PropTypes.shape({
        name: PropTypes.string,
      }),
      value: PropTypes.number,
    })
  ),
}
