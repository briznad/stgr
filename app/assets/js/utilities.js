var stgr;

stgr = stgr || {};

stgr.log = function(msg1, msg2) {
  'use strict';
  if ((typeof console !== "undefined" && console !== null) && (console.log != null)) {
    if (msg2) {
      return console.log(msg1, msg2);
    } else {
      return console.log(msg1);
    }
  }
};
