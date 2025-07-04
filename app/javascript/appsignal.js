/* global APPSIGNAL_API_KEY */

import Appsignal from '@appsignal/javascript'

const shouldEnableAppsignal = !!APPSIGNAL_API_KEY

export const appsignal = shouldEnableAppsignal
  ? new Appsignal({
      key: APPSIGNAL_API_KEY,
    })
  : undefined
