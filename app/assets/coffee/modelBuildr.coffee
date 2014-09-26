stgr = stgr or {}

stgr.modelBuildr = do ->
  'use strict'

  init = (callback) ->
    getData callback

  getData = (callback) ->
    # requesting data from API
    request = $.ajax
      url:    'http://stgr.thrillist.com:7847/list'

    # here's the data
    request.done (data) ->
      createCleanModel data, callback

    # uh-oh, something went wrong
    request.fail (data) ->
      stgr.model =
        settings: {}

      do callback

  createCleanModel = (data, callback) ->
    # add model object to stgr
    stgr.model =
      settings: {}
      servers: data.results

    do callback

  init: init