stgr = stgr or {}

stgr.updateView = do ->
  'use strict'

  beforeUpdate = (request) ->
    # false if /jpg$|jpeg$|png$|gif$|bmp$/.test request.path

  update = (type) ->
    # determine the current page object
    currentPage = stgr.model[type]

    # remove previous body classes
    do _removeBodyClasses

    # add current body classes
    _updateBodyClasses 'addClass', [
      type
    ]

    # update model with current page info
    _updateCurrentPage type

    # update page title and h1
    stgr.cache.$title.add(stgr.cache.$h1).text _computePageTitle type

    # render new view
    stgr.cache.$dynamicContainer.html stgr.template.primaryTemplate
      data:                   stgr.model
      currentType:            type
      currentPage:            currentPage

    do _registerEventListeners

  # fire GA event for each page load
  trackGA = (req) ->
    _gaq.push [
      '_trackPageview'
      req
    ]

  _updateBodyClasses = (method, classesArr) ->
    stgr.cache.$body[method] classesArr.join ' '

  _removeBodyClasses = ->
    # remove previous body classes
    if stgr.model.settings.currentPage
      _updateBodyClasses 'removeClass', [
        stgr.model.settings.currentPage.type
      ]

  _updateCurrentPage = (type) ->
    stgr.model.settings.currentPage = _.extend stgr.model.settings.currentPage or {},
      type: type

  _computePageTitle = (type) ->
    'stgr'

  _registerEventListeners = ->
    $('.accordian-unit').on 'click', (e) ->
      do e.stopPropagation

      $(this).toggleClass('expanded') unless $(e.target).is('a')

  beforeUpdate: beforeUpdate
  update:       update
  trackGA:      trackGA