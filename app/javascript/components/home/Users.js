import PropTypes from 'prop-types'
import React from 'react'
import {
  Bar,
  BarChart,
  Cell,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { CustomTooltip } from './components'
import { generateColor, USDollarNoCents, useDarkMode } from './utils'

export default function Users({ data }) {
  const isDark = useDarkMode()

  const maxNameLength = Math.max(...data.map(d => d.name.length))
  const charWidth = 8
  const yAxisWidth = Math.min(maxNameLength * charWidth, 120)

  return (
    <ResponsiveContainer
      width="100%"
      height={420}
      padding={{ top: 32, left: 40 }}
    >
      <BarChart data={data} layout="vertical" margin={{ left: 15 }}>
        <XAxis
          type="number"
          tickFormatter={n => {
            if (n >= 1000000) {
              return `$${(n / 1000000).toFixed(0)}M`
            }
            if (n >= 1000) {
              return `$${(n / 1000).toFixed(0)}K`
            }
            return USDollarNoCents.format(n)
          }}
          width={
            USDollarNoCents.format(Math.max(data.map(d => d['value']))).length *
            18
          }
        />
        <YAxis
          type="category"
          dataKey="name"
          textAnchor="end"
          interval={0}
          width={yAxisWidth}
          tick={{ width: yAxisWidth - 5 }}
          tickFormatter={v => {
            const maxChars = Math.floor(yAxisWidth / charWidth)
            if (v.length > maxChars) {
              return v.substring(0, maxChars - 1) + '…'
            }
            return v
          }}
        />
        <Tooltip content={CustomTooltip} cursor={{ fill: 'transparent' }} />
        <Bar dataKey="value" radius={[0, 5, 5, 0]}>
          {data.map((c, i) => (
            <Cell key={c.name} fill={generateColor(i, data.length, isDark)} />
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
