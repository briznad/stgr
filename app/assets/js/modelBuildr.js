var stgr;

stgr = stgr || {};

stgr.modelBuildr = (function() {
  'use strict';
  var getData, init, _collateProperties;
  init = function(callback) {
    return getData(callback);
  };
  getData = function(callback) {
    var request;
    request = $.ajax({
      url: 'http://stgr.thrillist.com:7847/list?verbose=true'
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
    init: init
  };
})();
