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

export default function Merchants({ data }) {
  const isDark = useDarkMode()

  return (
    <ResponsiveContainer width="100%" height={420} style={{ marginLeft: -20 }}>
      <BarChart data={data}>
        <YAxis
          tickFormatter={n => {
            if (n >= 1000000) {
              return `$${(n / 1000000).toFixed(0)}M`
            }
            if (n >= 1000) {
              return `$${(n / 1000).toFixed(0)}K`
            }
            return USDollarNoCents.format(n)
          }}
          width={65}
          tickMargin={0}
        />
        {data.length > 8 ? (
          <XAxis
            dataKey="name"
            textAnchor="end"
            verticalAnchor="start"
            interval={0}
            height={80}
            angle={-45}
          />
        ) : (
          <XAxis
            dataKey="name"
            interval={0}
            tick={({ x, y, payload }) => (
              <g transform={`translate(${x},${y})`}>
                {payload.value.split(' ').map((line, index) => (
                  <text
                    key={index}
                    x={0}
                    y={index * 10}
                    dy={16}
                    textAnchor="middle"
                    fill="#666"
                    fontSize={12}
                  >
                    {line}
                  </text>
                ))}
              </g>
            )}
          />
        )}
        <Tooltip content={CustomTooltip} cursor={{ fill: 'transparent' }} />
        <Bar dataKey="value" radius={[5, 5, 0, 0]}>
          {data.map((c, i) => (
            <Cell key={c.name} fill={generateColor(i, data.length, isDark)} />
          ))}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  )
}

Merchants.propTypes = {
  data: PropTypes.arrayOf(
    PropTypes.shape({
      name: PropTypes.string,
      value: PropTypes.number,
    })
  ).isRequired,
}
