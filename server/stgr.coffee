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
  devMode: true
  httpPort: 7847

app = do express

github = GitHub.client
    username: githubAuth.username
    password: githubAuth.password

githubRepo  = 'Thrillist/Pinnacle'
pinnacle    = github.repo githubRepo

queryInterval     = 10 # in minutes
recentlyChanged   = false
serverResults     = {}
serverData        = {}
serverList        = [
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

  # init server
  do initServer

  # init query
  do initQuery

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

  # initialize routes
  do initRoutes

  # locked & loaded!
  console.log '\n\n                  ####################\n                   s t g r  -  A P I\n                  ####################\n'

###
load routes
###
routes =
  'get' :
    '/'             : 'root'
    '/test'         : 'test'
    '/list'         : 'list'

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

    res.header 'Access-Control-Allow-Origin', '*'

    # if verbose query param is set, send detailed list
    unless /^$|true/.test req.query.verbose
      res.json
        recentlyChanged : recentlyChanged
        data            : serverResults
    else
      res.json
        recentlyChanged : recentlyChanged
        data            : serverData


###
init query
###
initQuery = ->
  t = setInterval ->
    do queryServers
  , 1000 * 60 * queryInterval

  do queryServers

queryServers = ->
  console.log '\nquerying staging servers'

  newResults = {}

  _.each serverList, (server) ->
    queryServer server, (currentBranch) ->
      newResults[server] = currentBranch

      if _.keys(newResults).length is serverList.length
        console.log '\n'
        console.log newResults

        compareResults newResults

queryServer = (server, callback = ->) ->
  # console.log '\nquerying server:\n' + server

  conn = new SSH()

  conn.on 'ready', ->
    conn.shell 'echo "test"', (err, stream) ->
      throw err if err

      output = []

      stream.stderr.on 'data', (data) ->
        console.error 'STDERR: ' + data

      stream.on 'data', (data) ->
        data = data.toString('utf8').replace /\s/g, ''

        # remove
        return false if data.length < 2 or /^\[/.test data

        # if the following command gets lumped in with the current line's output, cut it out
        data = data.split(/\[/)[0] if /\[/.test data

        output.push data

      stream.on 'close', ->
        do conn.end

        # console.log '\n' + server + ' responded:\n' + currentBranch

        callback do output.pop

      stream.end 'cd $(cat /etc/httpd/conf.d/pinnacle.conf | grep -m 1 DocumentRoot | sed s/DocumentRoot// | sed s/\\"//g)\ngit rev-parse --abbrev-ref HEAD\nexit\n'

  conn.connect
    host: server
    port: 22
    username: 'ec2-user'
    privateKey: file.readFileSync '/Users/bradmallow/Documents/keys/dops-dev.pem'

compareResults = (newResults) ->
  console.log '\ncomparing results'

  # create an object with only changed servers/branches
  changedServers = _.omit newResults, (value, key, object) ->
    return value is serverResults[key]

  changedCount = _.keys(changedServers).length

  if changedCount
    console.log '\nnew branches!'

    recentlyChanged = true
    serverResults   = newResults

    fetchMilestones (activeMilestones) ->
      addGithubData changedServers, changedCount, activeMilestones

  else
    console.log '\nno change'

    recentlyChanged = false

  console.log '\nchecking again in ' + queryInterval + ' minute/s'

fetchMilestones = (callback = ->) ->
  pinnacle.milestones
    page      : 1
    per_page  : 100
    state     : 'all'
    sort      : 'completeness'
  , (err, data, headers) ->
    if data
      # console.log '\n'
      # console.log data

      activeMilestones = {}

      _.each data, (milestone) ->
        if _.invert(serverResults)[milestone.title]
          activeMilestones[milestone.title] = milestone.number

    else
      console.log '\n'
      console.error 'error retrieving list of milestones'

    callback activeMilestones or {}

addGithubData = (changedServers, changedCount, activeMilestones) ->
  newServerData = {}

  _.each changedServers, (branch, server) ->
    queryGithub newServerData, server, branch, activeMilestones, ->
      if _.keys(newServerData).length is changedCount
        console.log '\nGithub querying complete!'

        serverData = _.extend serverData, newServerData

        console.log '\n'
        console.log serverData

queryGithub = (newServerData, server, branch, activeMilestones, callback = ->) ->
  # set flags to hackily get around async calls
  complete =
    branch    : false
    pull      : false
    labels    : false
    milestone : false

  callbackCheck = (type) ->
    complete[type] = true

    do callback if complete.branch and complete.pull and complete.labels and complete.milestone

  newServerData[server] =
    server    : server
    property  : server.split('.')[1]
    branch    :
      name      : branch

  queryBranch newServerData, server, branch, ->
    callbackCheck 'branch'

  queryPull newServerData, server, branch, ->
    callbackCheck 'pull'

    if newServerData[server].pull.number
      queryLabels newServerData, server, newServerData[server].pull.number, ->
        callbackCheck 'labels'

    else
      callbackCheck 'labels'

  queryMilestone newServerData, server, branch, activeMilestones, ->
    callbackCheck 'milestone'

queryBranch = (newServerData, server, branch, callback = ->) ->
  pinnacle.branch branch, (err, data, headers) ->
    if err
      if err.statusCode is 404
        newServerData[server].branch = _.extend newServerData[server].branch or {},
          name: branch
          open: false

      do callback

    else
      # console.log '\n'
      # console.log data

      newServerData[server].branch = _.extend newServerData[server].branch or {},
        name: data.name
        link: data._links.html
        open: true

      newServerData[server].last_commit = _.extend newServerData[server].last_commit or {},
        date: data.commit.commit.author.date
        message: data.commit.commit.message

      newServerData[server].author = _.extend newServerData[server].author or {},
        name: data.commit.author.login
        link: data.commit.author.html_url
        pic: data.commit.author.avatar_url

      do callback

queryPull = (newServerData, server, branch, callback = ->) ->
  pinnacle.prs
    page      : 1
    per_page  : 100
    head      : 'Thrillist:' + branch
    state     : 'all'
  , (err, data, headers) ->
    if data and data.length
      data = data[0]

      # console.log '\n'
      # console.log data

      newServerData[server].branch = _.extend newServerData[server].branch or {},
        name : data.head.ref
        link : 'https://github.com/Thrillist/Pinnacle/tree/' + data.head.ref

      newServerData[server].pull = _.extend newServerData[server].pull or {},
        open    : if data.state is 'open' then true else false
        merged  : if data.merged_at then true else false
        name    : data.title
        link    : data._links.html.href

      newServerData[server].author = _.extend newServerData[server].author or {},
        name  : data[if data.assignee then 'assignee' else 'user'].login
        link  : data[if data.assignee then 'assignee' else 'user'].html_url
        pic   : data[if data.assignee then 'assignee' else 'user'].avatar_url

    else
      newServerData[server].pull = false

    do callback

queryLabels = (newServerData, server, number, callback = ->) ->
  # query for a specific pull request's labels
  issue = github.issue githubRepo, number

  issue.info (err, data, headers) ->
    if err
      console.error err

      newServerData[server].pull.labels = false

    else if data
      # console.log '\n'
      # console.log data

      newServerData[server].pull.labels = []

      _.each data.labels, (label) ->
        newServerData[server].pull.labels.push
          link  : label.url.replace('api.github.com/repos', 'github.com').replace('+', '%20')
          color : '#' + label.color
          name  : label.name

    do callback

queryMilestone = (newServerData, server, branch, activeMilestones, callback = ->) ->
  if activeMilestones[branch]
    pinnacle.issues
      page      : 1
      per_page  : 100
      milestone : activeMilestones[branch]
      state     : 'all'
    , (err, data, headers) ->
      if data
        # console.log '\n'
        # console.log data[0]

      else
        newServerData[server].milestone = false

      do callback

  else
    newServerData[server].milestone = false

    do callback


do init