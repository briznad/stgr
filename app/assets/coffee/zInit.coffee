stgr = stgr or {}

stgr.init = do ->
  'use strict'

  # load templates
  stgr.template.init ->
    # retrieve json and build document model
    stgr.modelBuildr.init ->
      # load router controller
      do stgr.router.init