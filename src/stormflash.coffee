Array::unique = ->
  output = {}
  output[@[key]] = @[key] for key in [0...@length]
  value for key, value of output

StormData = require('stormagent').StormData
StormRegistry = require('stormagent').StormRegistry

class StormInstance extends StormData

    schema =
        name: "instance"
        type: "object"
        required: true
        properties:
            name : { type: "string", "required": true }
            id   : { type: "string", "required": false}
            path : { type: "string", "required": true }
            pid  : { type: "integer", "required" : false }
            monitorOn: { type: "boolean", "required" : false}
            args:
                type: "array"
                required: false
                items:
                    type: "string"
                    required: false


    constructor: (id, data) ->
        super id, data, schema



#-----------------------------------------------------------------


class StormInstances extends StormRegistry
    constructor: (filename) ->
        @on 'load', (key,val) ->
            entry = new StormInstance key,val
            if entry?
                entry.saved = true
                @add key, entry

        @on 'updated', (entry) ->
            @log "Updated entry with key #{entry.key} with pid #{entry.data.pid}"

        super filename

    # get storminstance details
    get: (key) ->
        entry = super key
        entry

    discover: ->
        for key of @entries
            entry = @entries[key]
            if entry? and entry.data? and entry.data.pid?
                if entry.data.monitor is true
                    @log "Emitting monitor for discovered pid #{entry.data.pid}"
                    entry.monitorOn = true
                    @emit "attachnMonitor", entry.data.pid, key
        

#-----------------------------------------------------------------

class StormPackage extends StormData
    schema =
        name: "package"
        type: "object"
        required: true
        properties:
            name : { type: "string", "required": true }
            id   : { type: "string", "required": false}
            version : { type: "string", "required": true }
            source : { type: "string", "required": true }
            status: { type: "string", "required": false}

    constructor: (id, data) ->
        super id, data, schema

#--------------------------------------------------------------------

class StormPackages extends StormRegistry
    constructor: (filename) ->
        @on 'load', (key,val) ->
            entry = new StormPackage key,val
            if entry?
                entry.saved = true
                @add key, entry

        @on 'removed', (key) ->
            # an entry is removed in Registry
            #
        super filename

    get: (key) ->
        entry = super key
        entry

    match: (pinfo) ->
        #@log "Dumping all entries", @entries
        for key of @entries
            entry = @entries[key]
            return unless entry? and entry.data?
            pkg = entry.data
            if (pkg.name is pinfo.name) and (pkg.version is pinfo.version) and (pkg.source is pinfo.source)
               pkg.id = entry.id
               return pkg


    find: (name, version) ->
        for key of @entries
            entry = @entries[key]
            return unless entry? and entry.data?
            pkg = entry.data
            if (pkg.name is name) and (pkg.version is version)
                #@log "Matching found"
                entry.data.id = entry.id
                return entry.data
                


#--------------------------------------------------------------------
StormBolt = require 'stormbolt'

class StormFlash extends StormBolt

    validate = require('json-schema').validate
    exec = require('child_process').exec
    fs = require 'fs'
    path = require 'path'
    uuid = require('node-uuid')

    constructor: (config) ->
        super config

        # key routine to import itself into agent base
        @import module

        @packages  = new StormPackages  "#{@config.datadir}/packages.db"
        @instances = new StormInstances "#{@config.datadir}/instances.db"

        @log 'loading spm...'
        spm = require('./spm').StormPackageManager
        @spm = new spm log:@log, repatInterval:@config.repeatInterval, import:@import
        @spm.on 'discovered', (pkgType, pinfo) =>
            pkg = @packages.find pinfo.name, pinfo.version
            unless pkg?
                pinfo.source = "builtin" unless pinfo.source?
                @log "Discovered package ", pinfo
                spkg = new StormPackage null, pinfo
                @packages.add uuid.v4(), spkg


        processmgr = require('./processmgr').ProcessManager
        @processmgr = new processmgr()


        @processmgr.on "error", (error, key, pid) =>
            #when a process failed to start, what should be done?
            @log "Error while starting the process for key #{key} ", error
            entry.status = "error"

        @processmgr.on "signal", (signal, pid, key) =>
            @log "recieved signal #{signal} from pid #{pid} with key #{key}"
            switch signal
                when "stopped", "killed", "exited"
                    #return if signal is null
                    entry = @instances.entries[key]
                    if entry? and entry.monitorOn is true
                        @log "Starting the process with #{entry.name}"
                        # process sent signal
                        @log "Sending stop signal to pid #{pid}"
                        @processmgr.stop pid, key
                        @start key, (key, pid) =>
                            if key instanceof Error
                                @log key
                                return

                when "error"
                    @log "Error in getting signals from process"

        @processmgr.on "attachError", (err, pid, key) =>
            @log 'attach error ', err, pid, key

            entry = @instances.entries[key]
            if entry isnt undefined and entry?
                entry.status = "error"
                @log "Failed to attach for pid " , pid , "Reason is ", err

        @processmgr.on "detachError", (err, pid, key) =>
            entry = @instances.entries[key]
            if entry isnt undefined and entry?
                entry.status = "error"
                @log "Failed to detach for pid " , pid , "Reason is ", err

        @processmgr.on "stopped", (signal, pid, key) =>
            # restart the process if entry has monitor option set
            # if stopped gracefully dont start it again
            @log "process stopped due to signal ", signal if signal?
            entry = @instances.entries[key] if key?
            if entry?
                @log "process was not running. pid expected is  ", pid , "binary name is ", entry.name if entry?
                #@processmgr.start  entry.name, entry.path, entry.args, entry.pid, key if entry? and entry.monitrOn is true
                @start  key, (key, pid) =>
                    if key instanceof Error
                        @log key
                        return

        @processmgr.on "attached", (result, pid, key) =>
            entry = @instances.entries[key]
            if entry?
                entry.status = "running|monitored"
                @log "process #{pid} with key #{key}  is attached"

        @instances.on "attachnMonitor", (pid, key) =>
            # need to attach and monitor it
            @log "Starting monitor on discovered pid #{pid} with key #{key}"
            @processmgr.attach pid, key
            @processmgr.monitor pid, key

        @processmgr.on "monitor", (pid, key) =>
            @log "Starting monitor on pid #{pid} with key #{key}"
            @processmgr.monitor pid, key


    status: ->
        state = super
        state.packages  = @packages.list()
        state.instances = @instances.list()
        state

    run: (config) ->
        super config

        # start monitoring the packages and processes
        @spm.monitor  @config.repeatInterval
        @instances.discover()

    install: (pinfo, callback) ->
        # check if already exists
        pkg = @packages.match pinfo
        if pkg?
            @log "Found matching package name #{pkg.name}"
            callback pkg

        @spm.install pinfo, @include, (pkg) =>
            # should return something other than 500...
            return callback pkg if pkg instanceof Error
            @packages.add uuid.v4(), pinfo
            @emit 'installed the package ', pinfo.name, pinfo.id
            callback pinfo


    uninstall: (pinfo, callback) ->

        pkg = @packages.match pinfo
        return 404 if pkg instanceof Error

        # Kill the instances and clean up StormInstance Registry
        instance = @instances.match pkg.name

        if instance?
            # one time event registration to stop the process
            @processmgr.once 'stop', (key, pid) ->
                #signal the process to stop
                @processmgr.stop pid, key
                @instances.remove key

            # Generate event to process Manager to stop the process
            @processmgr.emit 'stop', instance.key, instance.pid

        @spm.uninstall pinfo, (result) =>
            return callback 500 if result instanceof Error
            @packages.remove pkg.id
            @emit 'uinstalled', pkg.name, pkg.id
            callback result

    update: (module,entry, callback) ->
        if module.id
            @add module,entry, false, (res) =>
                unless res instanceof Error
                    callback res
                else
                    callback res
        else
            callback new Error "Could not find ID! #{id}"

    start: (key, callback) ->
        entry = @instances.entries[key]
        return callback new Error "Key #{key} does not exist in DB" unless entry? and entry.data?
        pid = @processmgr.start entry.data.name, entry.data.path, entry.data.args, key
        callback new Error "Not able to start the binary" unless pid?
        entry.data.pid = pid
        entry.monitorOn = true  if entry.data.monitor is true
        entry.saved = false
        @instances.update key, entry
        @processmgr.attach pid, key
        callback key, pid if callback?
        @processmgr.emit "monitor", pid, key if entry.monitorOn is true


    stop: (key, callback) ->
        entry = @instances.entries[key]
        return callback new Error "No running process" unless entry? and entry.data? and entry.data.pid?
        @log "Stopping the process with pid #{entry.data.pid}"
        entry.monitorOn = false
        entry.saved = false
        @instances.update key, entry
        return @processmgr.stop entry.data.pid, key

    restart: (key, callback) ->
        entry = @instances.entries[key]
        entry.monitorOn = false
        status = @processmgr.stop entry.data.pid, key
        unless status instanceof Error
            pid = @processmgr.start entry.data.name, entry.data.path, entry.data.args, key
            entry.data.pid = pid
            entry.saved = false
            entry.monitorOn = true if entry.data.monitor is true
            @instances.update key, entry





###
# SINGLETON CLASS OBJECT
###
module.exports.StormFlash = StormFlash
module.exports.StormInstance = StormInstance
module.exports.StormPackage = StormPackage

# instance = null
# module.exports = (args) ->
#     if not instance?
#         instance = new StormAgent args
#     return instance

#-------------------------------------------------------------------------------------------

if require.main is module

    ### 
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
        bolt:
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
    ###

    config = null
    storm = null # override during dev 
    agent = new StormFlash config

    agent.on "running", (include) =>
        console.log "running returned ", include
        agent.include = include
    agent.run storm

    # Garbage collect every 2 sec 
    # Run node with --expose-gc
    setInterval (
        () -> gc()
    ), 60000 if gc?
