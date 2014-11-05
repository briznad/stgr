stgr = stgr or {}

stgr.refreshData = do ->
  'use strict'

  init = (opts = {}) ->
    options = _.extend
      intervalInMinutes : 2
    , opts

    interval = setInterval _updateCheck, options.intervalInMinutes * 1000 * 60

  _updateCheck = ->
    # requesting last update timestamp from API
    request = $.ajax
      url:    'http://' + window.location.hostname + ':7847/lastChange'

    # here's the data
    request.done (data) ->
      # console.log 'last known change was at: ' + stgr.model.settings.lastChange
      # console.log 'latest known change was at: ' + data.lastChange

      if data.lastChange isnt stgr.model.settings.lastChange
        stgr.modelBuildr.getData stgr.updateView.update

  init: init