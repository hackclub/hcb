/* global APPSIGNAL_API_KEY */

import Appsignal from '@appsignal/javascript'

export const appsignal = new Appsignal({
  key: APPSIGNAL_API_KEY,
})
