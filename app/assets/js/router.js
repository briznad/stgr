var stgr;

stgr = stgr || {};

stgr.router = (function() {
  'use strict';
  var init, initRoutes, _testHash;
  init = function(callback) {
    if (callback == null) {
      callback = function() {};
    }
    initRoutes();
    _testHash();
    return callback();
  };
  initRoutes = function() {
    var routes;
    return routes = new Davis(function() {
      this.configure(function(config) {
        return config.generateRequestOnPageLoad = true;
      });
      this.before(stgr.updateView.beforeUpdate);
      this.after(function(req) {});
      this.get('/', function() {
        return stgr.updateView.update('root');
      });
      return this.get('/index.html', function() {
        return stgr.updateView.update('root');
      });
    });
  };
  _testHash = function() {
    if (location.hash) {
      return Davis.location.assign(new Davis.Request(location.hash.replace(/^#/, '')));
    }
  };
  return {
    init: init
  };
})();
