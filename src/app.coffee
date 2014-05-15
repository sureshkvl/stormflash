argv = require('minimist')(process.argv.slice(2))
if argv.h?
    console.log """
        -h view this help
        -p port number
        -l logfile
        -d datadir
    """
    return

config = {}
config.port    = argv.p ? 5000
config.logfile = argv.l ? "/var/log/stormflash.log"
config.datadir = argv.d ? "/var/stormstack"

storm = config.storm

# COMMENT OUT below "storm" object FOR REAL USE
# test storm data for manual config
# storm = null <-- should be the default
storm =
    provider: "openstack"
    tracker: "https://allow@stormtracker.dev.intercloud.net"
    skey: "some-secure-serial-key"
    id: "testing-uuid"
    cert: ""
    key: ""
    ca: ""
    uplinks: [ "bolt://stormtower.dev.intercloud.net" ]
    uplinkStrategy: "round-robin"
    allowRelay: true
    relayPort: 8017
    allowedPorts: [ 5000 ]
    listenPort: 443
    beaconInterval: 10
    beaconRetry: 3

# start the stormflash agent instance
StormFlash = require './stormflash'
agent = new StormFlash config
agent.on "zappa.ready", ->
    @log "starting activation..."
    @activate storm, (err, status) =>
        @log "activation completed with:\n", @inspect status

agent.on "activated", (storm) ->
    @log "firing up stormbolt..."
    stormbolt = @import 'stormbolt'
    try
        bolt = new stormbolt storm.bolt
        bolt.on "error", (err) =>
            @log "bolt error, force agent re-activation..."
            @activate config.storm, (err, status) =>
                @log "re-activation completed with #{status}"
        bolt.run()
    catch error
        @log "bolt fizzled... should do something smart here"
    @monitor storm, (err, status) =>

agent.run()

# Garbage collect every 2 sec
# Run node with --expose-gc
if gc?
    setInterval (
        () -> gc()
    ), 2000
