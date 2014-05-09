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
config=null

try
    config = JSON.parse fileops.readFileSync argv.config
catch error
    util.log error
    util.log "stormflash using default storm parameters..."
    # whether error with config parsing or not, we will handle using config
    config=
        port : 5000, #default port
        logfile : "/var/log/stormflash.log",
        datadir : "/var/stormflash",
        stormtracker : "auto",
        serialKey : "unknown",
        autobolt : true
finally
    util.log "stormflash infused with " + JSON.stringify config

#check and create the necessary data dirs
fs=require('fs')
try
    fs.mkdirSync("#{config.datadir}") unless fs.existsSync("#{config.datadir}")
    fs.mkdirSync("#{config.datadir}/db")  unless fs.existsSync("#{config.datadir}/db")
    fs.mkdirSync("#{config.datadir}/certs") unless fs.existsSync("#{config.datadir}/certs")
catch error
    util.log "Error in creating data dirs"


# start the stormflash web application
{@app} = require('zappajs') config.port, ->
    @configure =>
      @use 'bodyParser', 'methodOverride', @app.router, 'static'
      @set 'basepath': '/v1.0'

    @configure
      development: => @use errorHandler: {dumpExceptions: on, showStack: on}
      production: => @use 'errorHandler'

    @enable 'serve jquery', 'minify'
    @include './lib/api'

# activation logic starts here
if config.stormstack.enabled
    activation = require('./lib/activation')(config)
    # register event into activate for when "success"
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

