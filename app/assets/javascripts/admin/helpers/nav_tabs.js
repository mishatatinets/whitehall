(function() {
  "use strict";
  window.GOVUK = window.GOVUK || {};

  window.GOVUK.navTabs = {
    init: function init() {
      var url = document.location.toString();
      if (url.match('#')) {
        $('.nav-tabs a[href=#'+url.split('#')[1]+']').tab('show');
      }
      $(':not(.attachment-mode-select).nav-tabs a').on('shown', function (e) {
        var before_shown_scroll_y = window.pageYOffset;
        var before_shown_scroll_x = window.pageXOffset;
        window.location.hash = e.target.hash;
        window.scrollTo(before_shown_scroll_y, before_shown_scroll_y);
      });
    }
  };
}());
