var stgr;

stgr = stgr || {};

stgr.template = (function() {
  'use strict';
  var init, processTemplates;
  init = function(callback) {
    var request;
    request = $.ajax({
      url: '/assets/templates/templates.html',
      dataType: 'html'
    });
    request.done(function(data) {
      return processTemplates(data, callback);
    });
    return request.fail(function(data) {
      return processTemplates(stgr.dummyData().template(), callback);
    });
  };
  processTemplates = function(response, callback) {
    var $templates;
    $templates = $(response).filter('script[type="text/html"]');
    $templates.each(function() {
      return stgr.template[$(this).attr('id')] = _.template($(this).html());
    });
    return callback();
  };
  return {
    init: init
  };
})();
