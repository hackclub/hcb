import PropTypes from 'prop-types'
import React from 'react'
import { Cell, Legend, Pie, PieChart, Tooltip } from 'recharts'
import { CustomTooltip, renderLegend } from './components'
import { generateColor, useDarkMode } from './utils'

export default function Tags({ data }) {
  const isDark = useDarkMode()

  return (
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
          <Cell key={`cell-${i}`} fill={generateColor(i, isDark)} />
        ))}
      </Pie>
      <Tooltip content={CustomTooltip} />
      <Legend layout="horizontal" content={renderLegend} />
    </PieChart>
  )
}

Tags.propTypes = {
  data: PropTypes.arrayOf(
    PropTypes.shape({
      truncated: PropTypes.string,
      value: PropTypes.number,
    })
  ).isRequired,
}
