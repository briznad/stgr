var stgr;

stgr = stgr || {};

stgr.modelBuildr = (function() {
  'use strict';
  var getData, init, _collateProperties;
  init = function(callback) {
    if (callback == null) {
      callback = function() {};
    }
    return getData(callback);
  };
  getData = function(callback) {
    var request;
    if (callback == null) {
      callback = function() {};
    }
    request = $.ajax({
      url: 'http://' + window.location.hostname + ':7847/list?verbose=true'
    });
    request.done(function(data) {
      stgr.model = {
        settings: {
          lastChange: data.lastChange
        },
        servers: data.data,
        properties: _collateProperties(data.data)
      };
      return callback();
    });
    return request.fail(function(data) {
      stgr.model = {
        settings: {},
        servers: {},
        properties: {}
      };
      return callback();
    });
  };
  _collateProperties = function(servers) {
    var propertyObj;
    propertyObj = {};
    _.each(servers, function(serverData, server) {
      propertyObj[serverData.property] = propertyObj[serverData.property] || [];
      return propertyObj[serverData.property].push(server);
    });
    return propertyObj;
  };
  return {
    init: init,
    getData: getData
  };
})();
