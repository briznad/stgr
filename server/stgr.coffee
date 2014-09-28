console.log '\nstgr API server is warming up...\n'

###
load required modules
###
file        = require 'fs'
_           = require 'underscore'
SSH         = require 'ssh2'
express     = require 'express'
GitHub      = require 'octonode'
githubAuth  = require './github_credentials'

###
load global vars
###
settings =
  devMode: false
  httpPort: 7847

app = do express

github = GitHub.client
    username: githubAuth.username
    password: githubAuth.password

pinnacle = github.repo 'Thrillist/Pinnacle'

queryInterval   = 10 # in minutes
recentlyChanged = false
serverResults   = {}
serverData      = {}
serverListCount = 0
serverList      = [
  'yolo.thrillist.com'
  'mojo.thrillist.com'
  'stage-coach.thrillist.com'
  'beta.thrillist.com'
  'beta.thrillistmediagroup.com'
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

  # DEV
  do queryGithub

  # init routes
  # do initRoutes

  # init server
  # do initServer

  # init query
  # do initQuery

###
load routes
###
routes =
  'get' :
    '/'             : 'root'
    '/test'         : 'test'
    '/list'         : 'list'
    '/detailedList' : 'detailedList'
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
      recentlyChanged : recentlyChanged

  list: (req, res) ->
    console.log '\nOMG, a request!'
    console.info 'request made for:\n' + req.url

    # respond!!
    # res.header 'Access-Control-Allow-Origin', 'http://stgr.thrillist.com'
    res.header 'Access-Control-Allow-Origin', '*'
    res.json
      recentlyChanged : recentlyChanged
      data            : serverResults

  detailedList: (req, res) ->
    console.log '\nOMG, a request!'
    console.info 'request made for:\n' + req.url

    # respond!!
    # res.header 'Access-Control-Allow-Origin', 'http://stgr.thrillist.com'
    res.header 'Access-Control-Allow-Origin', '*'
    res.json
      recentlyChanged : recentlyChanged
      data            : serverData

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

  serverListCount = serverList.length

  do queryServers

queryServers = ->
  console.log '\nquerying staging servers'

  newResults = {}

  callback = ->
    if serverListCount is _.keys(newResults).length then compareResults newResults

  _.each serverList, (server) ->
    queryServer newResults, server, callback

queryServer = (newResults, server, callback) ->
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

        newResults[server] =
          name: server
          branch:
            name: currentBranch

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
    lastResults = serverResults
    serverResults = newResults
    checkDiff lastResults, serverResults

    t = setTimeout ->
      console.log '\n'
      console.log serverResults
    , 4000

  console.log '\nchecking again in ' + queryInterval + ' minute/s'

checkDiff = (lastResults, serverResults) ->
  # _.each serverResults, (serverData, serverName) ->
  #   if !lastResults[serverName] or !lastResults[serverName].branch or lastResults[serverName].branch.name isnt serverData.branch.name
  #     queryGithub serverName, serverData

queryGithub = (serverName, serverData) ->
  # pinnacle.milestones (err, data, headers) ->
  #   if err
  #     console.error err
  #   else
  #     console.log data

  # pinnacle.branch serverData.branch.name, (err, data, headers) ->
  #   if err
  #     if err.statusCode is 404
  #       serverResults[serverName] = _.extend serverResults[serverName],
  #         open: false
  #   else
  #     console.log '\n'
  #     console.log data

  #     _.extend serverResults[serverName],
  #         open: true
  #         branch:
  #           name: data.name
  #           link: data._links.html
  #         author:
  #           name: data.commit.author.login
  #           link: data.commit.author.html_url
  #           pic: data.commit.author.avatar_url
  #         last_commit:
  #           date: data.commit.commit.author.date
  #           message: data.commit.commit.message


  pullRequest = github.pr 'Thrillist/Pinnacle', 1848

  pullRequest.info (err, data, headers) ->
    if err
      console.error err
    else
      console.log data.merged

  # pr merged = data.merged
  # pr branch = data.head.ref

do init