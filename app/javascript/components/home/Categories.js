import React from 'react'
import { Tooltip, Cell, PieChart, Legend, Pie } from 'recharts'
import Intl from 'intl'
import 'intl/locale-data/jsonp/en-US'
import PropTypes from 'prop-types'
import { colors, shuffle } from './utils'

export const USDollar = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
})

export const USDollarNoCents = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  minimumFractionDigits: 0,
  maximumFractionDigits: 0,
})

const CustomTooltip = ({ active, payload }) => {
  if (active && payload && payload.length) {
    return (
      <div
        style={{
          color: 'white',
          background: '#1f2d3d',
          borderRadius: '8px',
          padding: '0.25rem 0.75rem',
        }}
      >
        {payload[0].payload.name} <br />
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

const renderLegend = props => {
  const { payload } = props
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

export default function Users({ data }) {
  let shuffled = shuffle(colors)
  return (
    <PieChart width={400} height={450}>
      <Pie
        data={data}
        dataKey="value"
        nameKey="truncated"
        cx="50%"
        cy="50%"
        outerRadius={115}
        fill="#82ca9d"
        label={({ percent }) =>
          percent > 0.1 ? `${(percent * 100).toFixed(0)}%` : ''
        }
        labelLine={false}
      >
        {data.map((_, index) => (
          <Cell key={`cell-${index}`} fill={shuffled[index % colors.length]} />
        ))}
      </Pie>
      <Tooltip content={CustomTooltip} />
      <Legend layout="horizontal" content={renderLegend} />
    </PieChart>
  )
}

Users.propTypes = {
  data: PropTypes.arrayOf(
    PropTypes.shape({
      truncated: PropTypes.string,
      value: PropTypes.number,
    })
  ).isRequired,
}
