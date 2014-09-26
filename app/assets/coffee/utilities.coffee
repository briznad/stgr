stgr = stgr or {}

stgr.log = (msg1, msg2) ->
  'use strict'

  if console? and console.log?
    if msg2
      console.log msg1, msg2
    else
      console.log msg1