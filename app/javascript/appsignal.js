/* global APPSIGNAL_FRONTEND */

import Appsignal from '@appsignal/javascript'
import { plugin as pathPlugin } from '@appsignal/plugin-path-decorator'
import { plugin as consolePlugin } from '@appsignal/plugin-breadcrumbs-console'

export const appsignal = new Appsignal({
  key: APPSIGNAL_FRONTEND,
  ignoreErrors: [
    /The request is not allowed by the user agent or the platform in the current context, possibly because the user denied permission\./,
  ],
})

appsignal.use(pathPlugin())
appsignal.use(consolePlugin())
