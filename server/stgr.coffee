console.log '\nstgr API server is warming up...\n'

###
 load general depencies / global vars
###
settings =
  devMode: false
  httpPort: 7847

file    = require 'fs'
_       = require 'underscore'
SSH     = require 'ssh2'
express = require 'express'
app     = do express

queryInterval   = 1 # in minutes
recentlyChanged = false
serverResults   = {}
serverListCount = 0
serverList      =
  thrillist: [
    'yolo.thrillist.com'
    'mojo.thrillist.com'
    'stage-coach.thrillist.com'
    'beta.thrillist.com'
  ]

  thrillistmediagroup: [
    'beta.thrillistmediagroup.com'
  ]

  supercompressor: [
    'beta.supercompressor.com'
    'duper.supercompressor.com'
  ]

###
init
###
init = ->
  # load express middleware
  app.use express.bodyParser()
  app.use express.cookieParser()

  # init routes
  do initRoutes

  # init server
  do initServer

  # init query
  do initQuery

###
load routes
###
routes =
  'get' :
    '/'     : 'root'
    '/test' : 'test'
    '/list' : 'listAll'
  # 'put' :
  #   '/update' : 'updateRequest'
  # 'post' :
  #   '/create' : 'createRequest'

###
init routes
###
initRoutes = ->
  _.each routes, (value, key) ->
    verb = key
    _.each value, (value, key) ->
      app[verb] key, routeHandlers[value]

###
register route handlers
###
routeHandlers =
  root: (req, res) ->
    console.log '\nOMG, a request!'
    console.info 'request made for:\n' + req.url

    # respond!!
    res.json stgrSays: 'Hello World!'

  test: (req, res) ->
    console.log '\nOMG, a request!'
    console.info 'request made for:\n' + req.url

    # respond!!
    res.header 'Access-Control-Allow-Origin', '*'
    res.json stgrSays: 'serving test!'

  recentlyChanged: (req, res) ->
    console.log '\nOMG, a request!'
    console.info 'request made for:\n' + req.url

    # respond!!
    # res.header 'Access-Control-Allow-Origin', 'http://stgr.thrillist.com'
    res.header 'Access-Control-Allow-Origin', '*'
    res.json
      recentlyChanged:  recentlyChanged

  listAll: (req, res) ->
    console.log '\nOMG, a request!'
    console.info 'request made for:\n' + req.url

    # respond!!
    # res.header 'Access-Control-Allow-Origin', 'http://stgr.thrillist.com'
    res.header 'Access-Control-Allow-Origin', '*'
    res.json
      recentlyChanged:  recentlyChanged
      results:          serverResults

###
init server
###
initServer = ->
  # have app listen
  app.listen settings.httpPort

  # server started
  console.info '\nserver started at http://127.0.0.1:' + settings.httpPort

  # ERROR catcher
  unless settings.devMode
    console.info '\nPROD: errors will be caught and logged'
    process.on 'uncaughtException', (err) ->
      console.log '\nCaught the following exception:\n' + err
  else
    console.info '\nDEV: errors will NOT be caught'

  # locked & loaded!
  console.log '\n\n                  ####################\n                   s t g r  -  A P I\n                  ####################\n'

###
init query
###
initQuery = ->
  t = setInterval ->
    do queryServers
  , 1000 * 60 * queryInterval

  serverListCount = countServers serverList
  console.log '\nserver count to be queried:\n' + serverListCount

  do queryServers

countServers = (listOfServers) ->
  count = 0

  _.each listOfServers, (value, key) ->
    count += _.keys(value).length

  return count

queryServers = ->
  console.log '\nquerying staging servers'

  newResults = {}

  callback = ->
    if serverListCount is countServers newResults then compareResults newResults

  _.each serverList, (value, key) ->
    property = key
    newResults[property] = {}

    _.each value, (value, key) ->
      queryServer newResults, property, value, callback

queryServer = (newResults, property, server, callback) ->
  # console.log '\nquerying server:\n' + server

  conn = new SSH()

  conn.on 'ready', ->
    conn.shell '', (err, stream) ->
      throw err if err

      output = []

      stream.on 'close', ->
        do conn.end

        currentBranch = do output.pop

        console.log '\n' + server + ' responded:\n' + currentBranch
        newResults[property][server] = currentBranch

        do callback

      stream.on 'data', (data) ->
        data = String(data).replace /\s/g, ''

        output.push data if data.length > 1 and !/^\[/.test data

      stream.stderr.on 'data', (data) ->
        console.log 'STDERR: ' + data

      stream.end('go\ngit rev-parse --abbrev-ref HEAD\nexit\n')

  conn.connect
    host: server
    port: 22
    username: 'ec2-user'
    privateKey: file.readFileSync '/Users/bradmallow/Documents/keys/dops-dev.pem'

compareResults = (newResults) ->
  console.log '\ncomparing results'

  if _.isEqual serverResults, newResults
    console.log '\nno change'
    recentlyChanged = false
  else
    console.log '\nnew branches!'
    recentlyChanged = true
    serverResults = newResults

  console.log '\nchecking again in ' + queryInterval + ' minute/s'

do init