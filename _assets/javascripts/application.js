import { Application } from '@hotwired/stimulus'
import { DynamicControllerResolver } from 'stimulus-resolvers'

window.Stimulus = Application.start()

DynamicControllerResolver.install(Stimulus, controllerName => {
  const path = `./controllers/${controllerName}_controller`
  return import(path).then(controller => controller.default)
})
