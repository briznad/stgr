var stgr;

stgr = stgr || {};

stgr.init = (function() {
  'use strict';
  return stgr.template.init(function() {
    return stgr.modelBuildr.init(function() {
      return stgr.router.init();
    });
  });
})();
