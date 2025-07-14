/* global APPSIGNAL_FRONTEND */

import Appsignal from '@appsignal/javascript'

export const appsignal = new Appsignal({
  key: APPSIGNAL_FRONTEND,
})
