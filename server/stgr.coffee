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

queryIntervalInMinutes = 10
queryInterval = 1000 * 60 * queryIntervalInMinutes
serverResults = {}
lastChange    = 0
serverData    = {}
serverList    = [
  'stage01.thrillist.com'
  'stage02.thrillist.com'
  'stage03.thrillist.com'
  'stage04.thrillist.com'
  'stage01.supercompressor.com'
  'stage02.supercompressor.com'
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
    '/lastChange'   : 'lastChange'
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

  lastChange: (req, res) ->
    console.log '\nOMG, a request!'
    console.info 'request made for:\n' + req.url

    # respond!!
    # res.header 'Access-Control-Allow-Origin', 'http://stgr.thrillist.com'
    res.header 'Access-Control-Allow-Origin', '*'
    res.json
      lastChange              : lastChange
      queryIntervalInMinutes  : queryIntervalInMinutes

  list: (req, res) ->
    console.log '\nOMG, a request!'
    console.info 'request made for:\n' + req.url

    responseObj =
      lastChange              : lastChange
      queryIntervalInMinutes  : queryIntervalInMinutes

    # if verbose query param is set, send detailed list
    responseObj.data =  unless /^$|true/.test req.query.verbose then serverResults else serverData

    res.header 'Access-Control-Allow-Origin', '*'
    res.json responseObj


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
    queryServer server, (currentBranch) ->
      if currentBranch
        newResults[server] = currentBranch
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
    response = if response.length then response.pop().split('Pinnaclebranch:')[1].split('Contrabranch:')[0] else 'logout'

    unless /\\|\/|logout|HEAD/.test response
      callback response
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

        output = []

        stream.stderr.on 'data', (data) ->
          console.error 'STDERR: ' + data

        stream.on 'data', (data) ->
          data = data.toString('utf8').replace /\s/g, ''

          # remove
          return false if data.length < 2

          # if the following command gets lumped in with the current line's output, cut it out
          data = data.split(/\[/)[0] if /\[/.test data

          output.push data if /Pinnaclebranch/.test data

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
    return value is serverResults[key]

  changedCount = _.keys(changedServers).length

  if changedCount
    console.log '\nnew branches!'

    lastChange    = Date.now()
    serverResults = newResults

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
        if _.invert(serverResults)[milestone.title]
          activeMilestones[milestone.title] = milestone.number

    callback activeMilestones

###
iterate through each changed server and pass it off to be Github query function
when done add this info to the serverData object
###
addGithubData = (changedServers, changedCount, activeMilestones) ->
  changedServersData = {}

  _.each changedServers, (branch, server) ->
    queryGithub server, branch, activeMilestones, (server, verboseData) ->
      changedServersData[server] = verboseData

      if _.keys(changedServersData).length is changedCount
        console.log '\nGithub querying complete!'

        serverData = _.extend serverData, changedServersData

        # ALL DONE
        # do printLineBreak
        # devLog changedServersData
        # devLog serverData

###
handle the various Github queries and fire callback when all have come back
###
queryGithub = (server, branch, activeMilestones, callback = ->) ->
  verboseData =
    server      : server
    property    : server.split('.')[1]
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


do init