import React from 'react'
import {
  Tooltip,
  ResponsiveContainer,
  BarChart,
  YAxis,
  Bar,
  Cell,
  XAxis,
  CartesianGrid,
} from 'recharts'
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
      value: PropTypes.number,
    })
  ),
}

export default function Users({ data }) {
  let shuffled = shuffle(colors)
  return (
    <ResponsiveContainer
      width="100%"
      height={420}
      padding={{ top: 32, left: 32 }}
    >
      <BarChart data={data} width={256} height={128}>
        <CartesianGrid strokeDasharray="3 3" />
        <YAxis
          tickFormatter={n => USDollarNoCents.format(n)}
          width={
            USDollarNoCents.format(Math.max(data.map(d => d['value']))).length *
            18
          }
        />
        {data.length > 8 ? (
          <XAxis
            dataKey="name"
            textAnchor="end"
            verticalAnchor="start"
            interval={0}
            angle={'-60'}
            height={80}
          />
        ) : (
          <XAxis dataKey="name" />
        )}
        <Tooltip content={CustomTooltip} />
        <Bar dataKey="value">
          {data.map((c, i) => (
            <Cell key={c.name} fill={shuffled[i % shuffled.length]} />
          ))}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  )
}

Users.propTypes = {
  data: PropTypes.arrayOf(
    PropTypes.shape({
      name: PropTypes.string,
      value: PropTypes.number,
    })
  ).isRequired,
}
