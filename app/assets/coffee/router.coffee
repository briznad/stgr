stgr = stgr or {}

stgr.router = do ->
  'use strict'

  init = (callback = ->) ->
    do initRoutes
    do _testHash
    do callback

  initRoutes = ->
    routes = new Davis ->
      @configure (config) ->
        config.generateRequestOnPageLoad = true

      @before stgr.updateView.beforeUpdate

      @after (req) ->
        # stgr.updateView.trackGA req.path

      @get '/', ->
        stgr.updateView.update 'root'

      @get '/index.html', ->
        stgr.updateView.update 'root'

  _testHash = ->
    if location.hash
      Davis.location.assign new Davis.Request location.hash.replace /^#/, ''

  init: init