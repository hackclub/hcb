// Load all the controllers within this directory and all subdirectories.
// Controller files must be named *_controller.js.

import { Application } from '@hotwired/stimulus'
import { definitionsFromContext } from '@hotwired/stimulus-webpack-helpers'
import { installErrorHandler } from '@appsignal/stimulus'
import { appsignal } from '../appsignal'

const application = Application.start()

installErrorHandler(appsignal, application)

const context = require.context('.', true, /_controller\.js$/)
application.load(definitionsFromContext(context))
