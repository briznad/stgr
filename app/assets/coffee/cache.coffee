stgr = stgr or {}

stgr.cache =

  $window:            $(window)
  $document:          $(document)
  $html:              $(document.documentElement) # document.documentElement === 'html'
  $body:              $(document.body)

  $title:             $('title')
  $h1:                $('h1')
  $dynamicContainer:  $('#dynamicContainer')