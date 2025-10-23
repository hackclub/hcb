import 'intl/locale-data/jsonp/en-US'
import PropTypes from 'prop-types'
import React from 'react'
import {
  Cell,
  Legend,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
} from 'recharts'
import { CustomTooltip, renderLegend } from './components'
import { generateColor, useDarkMode } from './utils'

export default function Categories({ data }) {
  const isDark = useDarkMode()

  return (
    <ResponsiveContainer
      width="100%"
      height={420}
      padding={{ top: 32, left: 32 }}
    >
      <PieChart width={400} height={420}>
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
          strokeWidth={2}
          stroke={isDark ? '#252429' : '#FFFFFF'}
        >
          {data.map((_, i) => (
            <Cell
              key={`cell-${i}`}
              style={{ outline: 'none' }}
              fill={generateColor(i, data.length, isDark)}
            />
          ))}
        </Pie>
        <Tooltip content={CustomTooltip} />
        <Legend layout="horizontal" content={renderLegend} />
      </PieChart>
    </ResponsiveContainer>
  )
}

Categories.propTypes = {
  data: PropTypes.arrayOf(
    PropTypes.shape({
      truncated: PropTypes.string,
      value: PropTypes.number,
    })
  ).isRequired,
}
