/* global AIRBRAKE_PROJECT_ID, AIRBRAKE_API_KEY */

import { Notifier } from '@airbrake/browser'

const environment = process.env.NODE_ENV || 'development'
const shouldEnableAirbrake = AIRBRAKE_PROJECT_ID && AIRBRAKE_API_KEY

const airbrake = shouldEnableAirbrake
  ? new Notifier({
      projectId: AIRBRAKE_PROJECT_ID,
      projectKey: AIRBRAKE_API_KEY,
      environment,
    })
  : undefined

airbrake?.addFilter(notice => {
  if (environment === 'development') return null
  return notice
})

airbrake?.addFilter(notice => {
  if (
    notice.errors
      .flatMap(e => e['messagePattern'])
      .some(e => e.includes('Failed to fetch'))
  )
    return null
  return notice
})

airbrake?.addFilter(notice => {
  if (
    notice.errors
      .flatMap(e => e.backtrace)
      .some(e => e.file?.startsWith('chrome-extension://'))
  )
    return null
  return notice
})

export default airbrake
