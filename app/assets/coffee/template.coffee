stgr = stgr or {}

stgr.template = do ->
  'use strict'

  init = (callback) ->
    request = $.ajax
      url: '/assets/templates/templates.html',
      dataType: 'html',

    request.done (data) ->
      processTemplates data, callback

    # uh-oh, something went wrong
    request.fail (data) ->
      processTemplates do stgr.dummyData().template, callback

  processTemplates = (response, callback) ->
    $templates = $(response).filter('script[type="text/html"]')

    $templates.each ->
      stgr.template[$(this).attr 'id'] = _.template $(this).html()

    do callback

  init: init