import PropTypes from 'prop-types'
import React from 'react'
import {
  FunnelChart,
  Funnel,
  Cell,
  Tooltip,
  LabelList,
  ResponsiveContainer,
} from 'recharts'
import { generateColor, useDarkMode } from '../home/utils'

const FunnelTooltip = ({ active, payload }) => {
  if (active && payload && payload.length) {
    const item = payload[0].payload
    return (
      <div
        style={{
          color: 'white',
          background: '#1f2d3d',
          borderRadius: '8px',
          padding: '0.5rem 0.75rem',
          boxShadow:
            '0 0 2px 0 rgba(0, 0, 0, 0.0625), 0 4px 8px 0 rgba(0, 0, 0, 0.125)',
        }}
      >
        <strong>{item.name}</strong>
        <br />
        {item.value.toLocaleString()}
        {item.pctOfTotal != null && (
          <span style={{ opacity: 0.7 }}> ({item.pctOfTotal}% of total)</span>
        )}
        {item.pctOfPrev != null && (
          <>
            <br />
            <span style={{ opacity: 0.7 }}>
              {item.pctOfPrev}% of previous stage
            </span>
          </>
        )}
      </div>
    )
  }
  return null
}

FunnelTooltip.propTypes = {
  active: PropTypes.bool,
  payload: PropTypes.array,
}

export default function ApplicationsFunnel({ data }) {
  const isDark = useDarkMode()

  const total = data.length > 0 ? data[0].count : 1

  const chartData = data.map((stage, i) => ({
    name: stage.label,
    value: stage.count,
    pctOfTotal: total > 0 ? ((stage.count / total) * 100).toFixed(1) : 0,
    pctOfPrev:
      i > 0 && data[i - 1].count > 0
        ? ((stage.count / data[i - 1].count) * 100).toFixed(1)
        : null,
  }))

  return (
    <ResponsiveContainer width="100%" height={400}>
      <FunnelChart>
        <Tooltip content={<FunnelTooltip />} />
        <Funnel dataKey="value" data={chartData} isAnimationActive>
          <LabelList
            position="right"
            fill={isDark ? '#ccc' : '#333'}
            stroke="none"
            dataKey="name"
            fontSize={13}
          />
          {chartData.map((_, i) => (
            <Cell
              key={i}
              fill={generateColor(i, chartData.length, isDark)}
            />
          ))}
        </Funnel>
      </FunnelChart>
    </ResponsiveContainer>
  )
}

ApplicationsFunnel.propTypes = {
  data: PropTypes.arrayOf(
    PropTypes.shape({
      label: PropTypes.string.isRequired,
      count: PropTypes.number.isRequired,
    })
  ).isRequired,
}
