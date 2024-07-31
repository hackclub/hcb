import React, { useEffect } from 'react'
import createPersistedState from 'use-persisted-state'
const useSnow = createPersistedState('shallItSnow')

export default function SnowToggle() {
  const emojis = {
    on: '⛄',
    off: '☁️',
  }

  const [snow, setSnow] = useSnow(true)

  const handleToggle = () => {
    setSnow(!snow)
  }

  useEffect(() => {
    if (snow) {
      console.log(`YEAHH! HOLIDAY SPIRIT\nSNOW MODE: ON ${emojis.on}`)
    } else {
      console.log(
        `It's alright, the holiday spirit ain't for everyone\nSNOW MODE: OFF ${emojis.off}`
      )
    }
  }, [snow])

  return (
    <>
      <div
        className="card card--hover cursor-pointer rounded-full h5 center flex items-center justify-center tooltipped tooltipped--e"
        style={{ width: '48px', height: '48px' }}
        onClick={handleToggle}
        aria-label="Toggle snow"
      >
        {snow ? emojis.on : emojis.off}
      </div>
    </>
  )
}
