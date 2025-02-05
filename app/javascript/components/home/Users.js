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

  return (
    <ResponsiveContainer
      width="100%"
      height={420}
      padding={{ top: 32, left: 32 }}
    >
      <BarChart data={data} layout="vertical">
        <XAxis
          type="number"
          tickFormatter={n => USDollarNoCents.format(n)}
          width={
            USDollarNoCents.format(Math.max(data.map(d => d['value']))).length *
            18
          }
        />
        <YAxis
          type="category"
          dataKey="name"
          textAnchor="end"
          verticalAnchor="start"
          interval={0}
          height={80}
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
