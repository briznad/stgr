stgr = stgr or {}

stgr.modelBuildr = do ->
  'use strict'

  init = (callback = ->) ->
    getData callback

  getData = (callback = ->) ->
    # requesting data from API
    request = $.ajax
      url:    'http://' + window.location.hostname + ':7847/list?verbose=true'

    # here's the data
    request.done (data) ->
      stgr.model =
        settings    :
          lastChange  : data.lastChange
        servers     : data.data
        properties  : _collateProperties data.data

      do callback

    # uh-oh, something went wrong
    request.fail (data) ->
      stgr.model =
        settings    : {}
        servers     : {}
        properties  : {}

      do callback

  _collateProperties = (servers) ->
    propertyObj = {}

    _.each servers, (serverData, server) ->
      propertyObj[serverData.property] = propertyObj[serverData.property] or []
      propertyObj[serverData.property].push server

    propertyObj

  init    : init
  getData : getData