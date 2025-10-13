import React from 'react'
import Snowfall from 'react-snowfall'

import createPersistedState from 'use-persisted-state'
const useSnow = createPersistedState('shallItSnow')

export default function Snow() {
  const [snow] = useSnow(true)

  return (
    <>
      {snow ? (
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
          <Snowfall />
        </div>
      ) : null}
    </>
  )
}
