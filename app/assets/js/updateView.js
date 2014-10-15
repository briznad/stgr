var stgr;

stgr = stgr || {};

stgr.updateView = (function() {
  'use strict';
  var beforeUpdate, trackGA, update, _computePageTitle, _registerEventListeners, _removeBodyClasses, _updateBodyClasses, _updateCurrentPage;
  beforeUpdate = function(request) {};
  update = function(type) {
    var currentPage;
    currentPage = stgr.model[type];
    _removeBodyClasses();
    _updateBodyClasses('addClass', [type]);
    _updateCurrentPage(type);
    stgr.cache.$title.add(stgr.cache.$h1).text(_computePageTitle(type));
    stgr.cache.$dynamicContainer.html(stgr.template.primaryTemplate({
      data: stgr.model,
      currentType: type,
      currentPage: currentPage
    }));
    return _registerEventListeners();
  };
  trackGA = function(req) {
    return _gaq.push(['_trackPageview', req]);
  };
  _updateBodyClasses = function(method, classesArr) {
    return stgr.cache.$body[method](classesArr.join(' '));
  };
  _removeBodyClasses = function() {
    if (stgr.model.settings.currentPage) {
      return _updateBodyClasses('removeClass', [stgr.model.settings.currentPage.type]);
    }
  };
  _updateCurrentPage = function(type) {
    return stgr.model.settings.currentPage = _.extend(stgr.model.settings.currentPage || {}, {
      type: type
    });
  };
  _computePageTitle = function(type) {
    return 'stgr';
  };
  _registerEventListeners = function() {
    return $('.accordian-unit').on('click', function(e) {
      e.stopPropagation();
      if (!$(e.target).is('a')) {
        return $(this).toggleClass('expanded');
      }
    });
  };
  return {
    beforeUpdate: beforeUpdate,
    update: update,
    trackGA: trackGA
  };
})();
