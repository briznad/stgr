stgrAPI
====

## Thrillist staging server RESTful endpoint

After checking out this project do the following to get stgrAPI up and running:

1. Make a copy of `EXAMPLE_github_credentials.coffee` called `github_credentials.coffee`, making sure to replace the `username` value with your [GitHub personal access token](https://github.com/blog/1509-personal-api-tokens).

1. Place your copy of `leeroy_id_rsa.pem` in this folder, aka the same folder as stgr.coffee. If you don't have a copy of `leeroy_id_rsa.pem` or don't know what I'm talking about, sorry, I can't help you.

1. run `npm install`

1. run `forever -w -c coffee stgr.coffee`, unless you'd like to run the API as a daemon. In that case run `forever start -c coffee stgr.coffee`.

### BOOM!!