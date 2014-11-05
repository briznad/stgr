var stgr;

stgr = stgr || {};

stgr.refreshData = (function() {
  'use strict';
  var init, _updateCheck;
  init = function(opts) {
    var interval, options;
    if (opts == null) {
      opts = {};
    }
    options = _.extend({
      intervalInMinutes: 2
    }, opts);
    return interval = setInterval(_updateCheck, options.intervalInMinutes * 1000 * 60);
  };
  _updateCheck = function() {
    var request;
    request = $.ajax({
      url: 'http://' + window.location.hostname + ':7847/lastChange'
    });
    request.done(function(data) {
      if (data.lastChange !== stgr.model.settings.lastChange) {
        return stgr.modelBuildr.getData(stgr.updateView.update);
      }
    });
    return request.fail(function() {
      var t;
      return t = setTimeout(_updateCheck, 30000);
    });
  };
  return {
    init: init
  };
})();
