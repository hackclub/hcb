import React from 'react'
import Snowfall from 'react-snowfall'

export default function Snow() {
  return (
    <>
      <div
        style={{
          position: 'fixed',
          top: 0,
          left: 0,
          width: '100%',
          height: '100%',
          zIndex: 9999,
          pointerEvents: 'none',
        }}
      >
        <Snowfall snowflakeCount={75} />
      </div>
    </>
  )
}
