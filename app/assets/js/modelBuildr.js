var stgr;

stgr = stgr || {};

stgr.modelBuildr = (function() {
  'use strict';
  var createCleanModel, getData, init;
  init = function(callback) {
    return getData(callback);
  };
  getData = function(callback) {
    var request;
    request = $.ajax({
      url: 'http://stgr.thrillist.com:7847/detailedList'
    });
    request.done(function(data) {
      return createCleanModel(data, callback);
    });
    return request.fail(function(data) {
      stgr.model = {
        settings: {}
      };
      return callback();
    });
  };
  createCleanModel = function(data, callback) {
    stgr.model = {
      settings: {},
      servers: data.results
    };
    return callback();
  };
  return {
    init: init
  };
})();
