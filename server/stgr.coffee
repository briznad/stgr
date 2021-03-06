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

githubRepo  = 'Thrillist/Pinnacle'
pinnacle    = github.repo githubRepo

queryIntervalInMinutes = 2
queryInterval = 1000 * 60 * queryIntervalInMinutes
lastChange    = 0
data          =
  serverResults : {}
  serverData    : {}
serverList    = []
propertyList  = [
  'thrillist'
  'supercompressor'
  'jackthreads'
  'thrillistmediagroup'
]

###
helper utilities
###
devLog = (msg) ->
  console.log msg

printLineBreak = ->
  console.log '\n'

###
init
###
init = ->
  # init server
  do initServer

  # init server list, then init server query
  initServerList initQuery

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
init routes
###
initRoutes = ->
  _.each apiResources, (methodRoutes, method) ->
    _.each methodRoutes, (route, routeFunction) ->
      app[method] route, routeHandlers[routeFunction]

###
define routes
###
apiResources =
  'get' :
    'root'        : [
      '/'
      '/api/v2/'
    ]
    'test'        : [
      '/test'
      '/api/v2/test'
    ]
    'lastChange'  : [
      '/lastChange'
      '/api/v2/lastChange'
    ]
    'list'        : [
      '/list'
      '/api/v2/servers'
      '/api/v2/servers/:server'
    ]

  # 'put' :
  #   '/update' : 'updateRequest'
  # 'post' :
  #   '/create' : 'createRequest'

###
define route handlers
###
routeHandlers =
  root: (req, res) ->
    console.log '\nOMG, a request!'
    console.info 'request made for:\n' + req.url

    # respond!!
    res.header 'Access-Control-Allow-Origin', '*'
    res.json stgrSays: 'Hello World!'

  test: (req, res) ->
    console.log '\nOMG, a request!'
    console.info 'request made for:\n' + req.url

    # respond!!
    res.header 'Access-Control-Allow-Origin', '*'
    res.json stgrSays: 'serving test!'

  lastChange: (req, res) ->
    console.log '\nOMG, a request!'
    console.info 'request made for:\n' + req.url

    # respond!!
    res.header 'Access-Control-Allow-Origin', '*'
    res.json
      lastChange              : lastChange
      queryIntervalInMinutes  : queryIntervalInMinutes

  list: (req, res) ->
    console.log '\nOMG, a request!'
    console.info 'request made for:\n' + req.url

    # if verbose query param is set, send detailed list
    useList = unless /^$|true/.test req.query.verbose then 'serverResults' else 'serverData'

    responseObj =
      lastChange              : lastChange
      queryIntervalInMinutes  : queryIntervalInMinutes
      data                    : if req.params.server then data[useList][req.params.server] else data[useList]

    res.header 'Access-Control-Allow-Origin', '*'
    res.json responseObj

###
set interval to check on available servers
###
initServerList = (callback = ->) ->
  t = setInterval ->
    do collateServers
  , 21600000 # update server list every 6 hours

  collateServers callback

###
create list of available servers
###
collateServers = (callback = ->) ->
  console.info 'determining which staging servers are in play'

  possibleServers = 100
  returnedResults = 0
  foundServers    = []

  _.each propertyList, (property) ->
    _.times possibleServers, (n) ->
      n++

      if n.toString().length is 1 then n = '0' + n

      pingServer 'stage' + n + '.' + property + '.com', (validServer) ->
        returnedResults++

        foundServers.push validServer if validServer

        if returnedResults is possibleServers * propertyList.length
          serverList = foundServers

          do callback

###
check for ssh access to server
###
pingServer = (server, callback) ->
  conn = new SSH()

  conn.on 'ready', ->
    callback server

  conn.on 'error', (error) ->
    callback false

  conn.connect
    host: server
    port: 22
    username: 'leeroy'
    privateKey: file.readFileSync 'leeroy_id_rsa.pem'

###
init query
###
initQuery = ->
  t = setInterval ->
    do queryServers
  , queryInterval

  do queryServers

###
iterate through the staging servers and hand off to be checked
###
queryServers = ->
  console.log '\nquerying staging servers'

  newResults = {}
  serverCount = serverList.length

  _.each serverList, (server) ->
    queryServer server, (currentBranches) ->
      if currentBranches
        newResults[server] = currentBranches
      else
        serverCount--;

      if _.keys(newResults).length is serverCount
        # do printLineBreak
        # devLog newResults

        compareResults newResults

###
ask each staging server what branch they're running
###
queryServer = (server, callback = ->) ->
  # console.log '\nquerying server:\n' + server
  maxAttempts   = 10
  connAttempts  = 0

  # test for forward or backward slashes, aka things that shouldn't be in a branch
  # if found, rerun branch check
  validateResponse = (response) ->
    if response? and !/\\|\/|HEAD/.test response
      callback
        pinnacle  : response.split('Pinnaclebranch:')[1].split('Contrabranch:')[0]
        contra    : response.split('Contrabranch:')[1]

    else if connAttempts >= maxAttempts
      callback false

    else
      do printLineBreak
      console.info 'uh-oh, SSH branch check ' + connAttempts + ' of ' + maxAttempts + ' for server ' + server + ' returned bad data\ntrying again'

      do doQueryServer

  doQueryServer = ->
    connAttempts++;

    conn = new SSH()

    conn.on 'ready', ->
      conn.shell 'echo "test"', (err, stream) ->
        throw err if err

        output = null

        stream.stderr.on 'data', (data) ->
          console.error 'STDERR: ' + data

        stream.on 'data', (data) ->
          data = data.toString('utf8').replace /\s/g, ''

          # remove
          return false if data.length < 2

          # if the following command gets lumped in with the current line's output, cut it out
          data = data.split(/\[/)[0] if /\[/.test data

          output = data if /Pinnaclebranch/.test(data) and /Contrabranch/.test(data)

        stream.on 'close', ->
          do conn.end

          # do printLineBreak
          # devLog server + ' responded:'
          # do printLineBreak
          # devLog currentBranch

          validateResponse output

        stream.end 'cat /tmp/' + server.split('.')[1].toUpperCase() + '_CURRENT_BRANCHES\nexit\n'

    conn.connect
      host: server
      port: 22
      username: 'leeroy'
      privateKey: file.readFileSync 'leeroy_id_rsa.pem'

  # initial server query
  do doQueryServer

###
check to see if any servers have changed
###
compareResults = (newResults) ->
  console.log '\ncomparing results'

  # create an object with only changed servers/branches
  changedServers = _.omit newResults, (value, key, object) ->
    return _.isEqual value, data.serverResults[key]

  changedCount = _.keys(changedServers).length

  if changedCount
    console.log '\nnew branches!'

    lastChange    = Date.now()

    # ensure serverResults are sorted properly
    data.serverResults = objSort newResults

    fetchMilestones (activeMilestones) ->
      addGithubData changedServers, changedCount, activeMilestones

  else
    console.log '\nno change'

  console.info '\nchecking again in ' + queryIntervalInMinutes + ' minute/s'

###
fetch all milestones from Github
###
fetchMilestones = (callback = ->) ->
  activeMilestones = {}

  pinnacle.milestones
    page      : 1
    per_page  : 100
    state     : 'all'
    sort      : 'completeness'
  , (err, data, headers) ->
    unless err
      # do printLineBreak
      # devLog data

      _.each data, (milestone) ->
        if _.invert(data.serverResults)[milestone.title]
          activeMilestones[milestone.title] = milestone.number

    callback activeMilestones

###
iterate through each changed server and pass it off to be Github query function
when done add this info to the serverData object
###
addGithubData = (changedServers, changedCount, activeMilestones) ->
  changedServersData = {}

  _.each changedServers, (branch, server) ->
    queryGithub server, branch.pinnacle, activeMilestones, (server, verboseData) ->
      changedServersData[server] =
        server    : server
        property  : server.split('.')[1]
        branches  :
          contra    : branch.contra
          pinnacle  : verboseData

      if _.keys(changedServersData).length is changedCount
        console.log '\nGithub querying complete!'

        # extend serverData, sort, and save
        data.serverData = objSort _.extend data.serverData, changedServersData

        # ALL DONE
        # do printLineBreak
        # devLog changedServersData
        # devLog data.serverData

###
handle the various Github queries and fire callback when all have come back
###
queryGithub = (server, branch, activeMilestones, callback = ->) ->
  verboseData =
    last_commit : false
    milestone   : false
    author      : false
    pull        : false
    branch      :
      name        : branch
      link        : 'https://github.com/Thrillist/Pinnacle/tree/' + branch
      open        : false

  # set flags to hackily get around async calls
  complete =
    branch    : false
    pull      : false
    labels    : false
    milestone : false

  callbackCheck = (type) ->
    complete[type] = true

    if complete.branch and complete.pull and complete.labels and complete.milestone then callback server, verboseData

  queryBranch branch, (queryBranchData = {}) ->
    verboseData = _.extend verboseData, queryBranchData
    callbackCheck 'branch'

  queryPullByBranch branch, verboseData.author, (queryPullData = {}) ->
    verboseData = _.extend verboseData, queryPullData
    callbackCheck 'pull'

    if verboseData.pull and verboseData.pull.number
      queryLabels verboseData.pull.number, (queryLabelsData = []) ->
        verboseData.pull.labels = queryLabelsData
        callbackCheck 'labels'

    else callbackCheck 'labels'

  # query for milestone
  if activeMilestones[branch]
    queryMilestone activeMilestones[branch], (queryMilestoneData = {}) ->
      verboseData.milestone = queryMilestoneData
      callbackCheck 'milestone'

  else callbackCheck 'milestone'

###
query Github for branch info
###
queryBranch = (branch, callback = ->) ->
  queryBranchData = {}

  pinnacle.branch branch, (err, data, headers) ->
    unless err
      # do printLineBreak
      # devLog data

      queryBranchData.branch =
        name: data.name
        link: data._links.html
        open: true

      queryBranchData.last_commit =
        date: data.commit.commit.author.date
        message: data.commit.commit.message

      queryBranchData.author =
        name: data.commit.author.login
        link: data.commit.author.html_url
        pic: data.commit.author.avatar_url

    callback queryBranchData

###
query Github for pull request info by specifying the branch name
###
queryPullByBranch = (branch, currentAuthor, callback = ->) ->
  queryPullData = {}

  pinnacle.prs
    page      : 1
    per_page  : 1
    head      : 'Thrillist:' + branch
    state     : 'all'
  , (err, data, headers) ->
    if data and data.length
      data = data[0]

      # do printLineBreak
      # devLog data

      queryPullData.pull =
        number  : data.number
        open    : if data.state is 'open' then true else false
        merged  : if data.merged_at then true else false
        name    : data.title
        link    : data._links.html.href

      queryPullData.author = _.extend
        name  : data[if data.assignee then 'assignee' else 'user'].login
        link  : data[if data.assignee then 'assignee' else 'user'].html_url
        pic   : data[if data.assignee then 'assignee' else 'user'].avatar_url
      , currentAuthor or {} # extend in case branchQuery has already come back with richer data

      queryPullData.labels = []

    callback queryPullData

###
query Github for label info
###
queryLabels = (number, callback = ->) ->
  queryLabelsData = []

  # query for a specific pull request's labels
  issue = github.issue githubRepo, number

  issue.info (err, data, headers) ->
    unless err
      # do printLineBreak
      # devLog data

      _.each data.labels, (label) ->
        queryLabelsData.push
          link  : label.url.replace('api.github.com/repos', 'github.com').replace('+', '%20')
          color : '#' + label.color
          name  : label.name

    callback queryLabelsData

###
query Github for milestone info
###
queryMilestone = (number, callback = ->) ->
  queryMilestoneData = {}

  pinnacle.issues
    page      : 1
    per_page  : 100
    milestone : number
    state     : 'all'
  , (err, data, headers) ->
    unless err
      # do printLineBreak
      # devLog data[0]

      queryMilestoneData =
        open          : if data[0].milestone.state is 'open' then true else false
        open_issues   : data[0].milestone.open_issues
        closed_issues : data[0].milestone.closed_issues

      issues = []

      _.each data, (issue) ->
        issueLabels = []

        _.each issue.labels, (label) ->
          issueLabels.push
            link  : label.url.replace('api.github.com/repos', 'github.com').replace('+', '%20')
            color : '#' + label.color
            name  : label.name

        tempIssue =
          labels  : issueLabels
          author  :
            name    : issue[if issue.assignee then 'assignee' else 'user'].login
            link    : issue[if issue.assignee then 'assignee' else 'user'].html_url
            pic     : issue[if issue.assignee then 'assignee' else 'user'].avatar_url
          pull    :
            number  : issue.number
            open    : if issue.state is 'open' then true else false
            name    : issue.title
            link    : issue.html_url

        queryPullByNumber issue.number, (queryPullData = {}) ->
          issues.push _.extend tempIssue, queryPullData

          if issues.length is data.length
            # got all milestone data
            queryMilestoneData.issues = issues
            callback queryMilestoneData

    else callback queryMilestoneData

###
query Github for pull request info by specifying the pull number
###
queryPullByNumber = (number, callback = ->) ->
  queryPullData = {}

  # query for a specific pull request
  pull = github.pr githubRepo, number

  pull.info (err, data, headers) ->
    unless err
      # do printLineBreak
      # devLog data

      queryPullData.branch =
        name : data.head.ref
        link : 'https://github.com/Thrillist/Pinnacle/tree/' + data.head.ref

      queryPullData.pull =
        number  : data.number
        open    : if data.state is 'open' then true else false
        merged  : if data.merged_at then true else false
        name    : data.title
        link    : data.html_url

    callback queryPullData

###
object sorter helper function
###
objSort = (obj) ->
  tempObj = {}

  _.each _.keys(obj).sort(), (value) ->
    tempObj[value] = obj[value]

  tempObj

###
LETS DO THIS THING!
###
do init