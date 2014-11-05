var stgr;

stgr = stgr || {};

stgr.init = (function() {
  'use strict';
  return stgr.template.init(function() {
    return stgr.modelBuildr.init(function() {
      stgr.router.init();
      return stgr.refreshData.init();
    });
  });
})();
