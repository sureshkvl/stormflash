argv = require('optimist')
    .usage('Start stormflash agent with a configuration file.\nUsage: $0')
    .demand('c')
    .default('c','/etc/stormstack/stormflash.json')
    .alias('c', 'config')
    .describe('c', 'location of stormflash configuration file')
    .argv

util=require('util')

util.log "stormflash agent brewing up a new storm..."
# config file processing logic block
fs = require 'fs'
config=null

try
    config = JSON.parse fs.readFileSync argv.config
catch error
    util.log error
    util.log "stormflash agent using default storm parameters..."
    # whether error with config parsing or not, we will handle using config
    config=
        port : 8000, #default port
        logfile : "/var/log/stormflash.log",
        datadir : "/var/stormflash",
        stormtracker : "auto",
        serialKey : "unknown",
        autobolt : true
finally
    util.log "stormflash agent infused with:\n" + util.inspect config

#check and create the necessary data dirs
fs=require('fs')
try
    fs.mkdirSync("#{config.datadir}") unless fs.existsSync("#{config.datadir}")
    fs.mkdirSync("#{config.datadir}/db")  unless fs.existsSync("#{config.datadir}/db")
    fs.mkdirSync("#{config.datadir}/certs") unless fs.existsSync("#{config.datadir}/certs")
catch error
    util.log "Error in creating data dirs"

storm = config.storm

# test storm data for manual config
storm =
    provider: "openstack"
    tracker: "https://allow@stormtracker.dev.intercloud.net"
    skey: "some-secure-serial-key"
    id: "testing-uuid"
    cert: ""
    key: ""
    bolt:
        remote: "bolt://bolt.dev.intercloud.net"
        listen: 123
        local: 8017
        local_forwarding_ports: [ 8000 ]
        beacon:
            interval: 10
            retry: 3

# start the stormflash agent instance
StormAgent = require './stormagent'
agent = new StormAgent config
agent.on "ready", ->
    @log "loading API endpoints"
    @include './api'
    @log "starting activation..."
    @activate storm, (err, status) =>
        @log "activation completed with ", JSON.stringify status

agent.on "active", (storm) ->
    @log "firing up stormbolt..."
    stormbolt = require 'stormbolt'
    bolt = new stormbolt storm
    # bolt.on "error", (err) =>
    #     @log "bolt error, force agent re-activation..."
    #     @activate config.storm, (err, status) =>
    #         @log "re-activation completed with #{status}"
    #bolt.start()

agent.run()


