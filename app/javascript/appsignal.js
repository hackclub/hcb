/* global APPSIGNAL_FRONTEND */

import Appsignal from '@appsignal/javascript'
import { plugin as pathPlugin } from '@appsignal/plugin-path-decorator'
import { plugin as consolePlugin } from '@appsignal/plugin-breadcrumbs-console'

export const appsignal = new Appsignal({
  key: APPSIGNAL_FRONTEND,
})

appsignal.use(pathPlugin())
appsignal.use(consolePlugin())
