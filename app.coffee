argv = require('optimist')
    .usage('Start stormflash with a configuration file.\nUsage: $0')
    .demand('c')
    .default('c','/etc/stormstack/stormflash.json')
    .alias('c', 'config')
    .describe('c', 'location of stormflash configuration file')
    .argv

util=require('util')

util.log "stormflash brewing up a new storm..."
# config file processing logic block
fileops = require("fileops")
try
    config = JSON.parse fileops.readFileSync argv.confg
catch error
    util.log error
    util.log "stormflash using default storm parameters..."
finally
    # whether error with config parsing or not, we will handle using config
    config.port ?= 5000 #default port
    config.logfile ?= "/var/log/stormflash.log"
    config.datadir ?= "/var/stormflash"
    config.autobolt ?= true

    util.log "stormflash infused with " + config

# start the stormflash web application
{@app} = require('zappajs') config.port, ->
    @configure =>
      @use 'bodyParser', 'methodOverride', @app.router, 'static'
      @set 'basepath': '/v1.0'

    @configure
      development: => @use errorHandler: {dumpExceptions: on, showStack: on}
      production: => @use 'errorHandler'

    @enable 'serve jquery', 'minify'
    @include './lib/plugins'
    @include './lib/packages'
    @include './lib/personality'
    @include './lib/environment'

# activation logic starts here
if config.autobolt
    activation = require('./lib/activation')

    # register event into activate for when "success"
    #
    # 1. import stormbolt and start it
    activation.on "success", (data) =>
        util.log 'received activattion success event with bolt config data ', data
        stormbolt = require ('stormbolt')
        bolt = new stormbolt data
        bolt.start (res) ->
           if res instanceof Error
                util.log 'bolt error: ' + res

    activation.on "failure", (data) =>
        util.log 'received activation failure event with data ', data

    activation.start()
    util.log "automatic bolt configuration in progres...."

