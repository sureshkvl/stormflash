Array::unique = ->
  output = {}
  output[@[key]] = @[key] for key in [0...@length]
  value for key, value of output

StormData = require('stormagent').StormData
StormRegistry = require('stormagent').StormRegistry
query = require('dirty-query').query
async = require('async')

class StormInstance extends StormData

    schema =
        name: "instance"
        type: "object"
        required: true
        additionalProperties: true
        properties:
            name : { type: "string", "required": true }
            id   : { type: "string", "required": false}
            path : { type: "string", "required": true }
            pid  : { type: "integer", "required" : false }
            monitor: { type: "boolean", "required" : false}
            status: { type: "string", "required": false}
            options:
                type: "object"
                required: false
            args:
                type: "array"
                required: false
                items:
                    type: "string"
                    required: false


    constructor: (data) ->
        super null, data, schema

#-----------------------------------------------------------------


class StormInstances extends StormRegistry
    constructor: (filename) ->
        @on 'load', (key,val) ->
            entry = new StormInstance val
            if entry?
                entry.saved = true
                entry.id = key
                @add key, entry

        @on 'updated', (entry) ->
            @log "Updated entry with key #{entry.id} with pid #{entry.data.pid}"

        super filename

    # get storminstance details
    get: (key) ->
        entry = super key
        return unless entry?
        if entry.data?
            entry.data.id = entry.id
            entry.data
        else
            entry

    discover: ->
        for key of @entries
            entry = @entries[key]
            if entry? and entry.data? and entry.data.pid?
                if entry.data.monitor is true
                    @log "Emitting monitor for discovered pid #{entry.data.pid}"
                    entry.monitorOn = true
                    @emit "attachnMonitor", entry.data.pid, key

    match: (name) ->
        #@log "Dumping all entries", @entries
        for key of @entries
            entry = @entries[key]
            return unless entry? and entry.data?
            instance  = entry.data
            if (instance.name is name)
               instance.id = entry.id
               return instance


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
            status:
                type: "object"
                required: false
                properties:
                    installed: { type: "boolean", "required": false}
                    imported:  { type: "boolean", "required" : false}
            type:   { type: "string", "required": false}

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
        return unless entry?
        if entry.data?
            entry.data.id = entry.id
            entry.data
        else
            entry

    match: (pinfo) ->
        @log "Matching the package #{pinfo.name} with db"
        packages = query @db, {name:pinfo.name, version:pinfo.version}
        unless packages
            packages = query @db, {name:pinfo.name, version:"*"}
        @log "Matched Package #{pinfo.name}" if packages[0]?
        packages[0]


    find: (name, version) ->
        packages = query @db, {name:name, version:version}
        unless packages?
            packages = query @db, {name:name, version:"*"}
        @log "Found Package #{name} " if packages[0]?
        packages[0]



#--------------------------------------------------------------------
StormBolt = require 'stormbolt'

class StormFlash extends StormBolt

    validate = require('json-schema').validate
    exec = require('child_process').exec
    fs = require 'fs'
    path = require 'path'
    uuid = require('node-uuid')
    spm = require './spm'
    processmgr = require('./processmgr')

    constructor: (config) ->
        super config

        # key routine to import itself into agent base
        @import module
        fs.mkdir "#{@config.datadir}", () ->
        fs.mkdir "#{@config.datadir}/plugins", () ->

        @services = new StormRegistry
        @packages  = new StormPackages  "#{@config.datadir}/packages.db"
        @instances = new StormInstances "#{@config.datadir}/instances.db"
        @instances.on 'ready', () =>
            @instances.discover()

    status: ->
        state = super
        state.packages  = @packages.list()
        state.services  = @services.list()
        state.instances = @instances.list()
        state

    run: (config) ->
        super config

        @log 'loading Storm Package Manager...'
        @spm = new spm log:@log, repeatInterval:@config.repeatInterval

        @spm.on 'discovered', (pkgType, pinfo) =>
            pkg = @packages.find pinfo.name, pinfo.version
            unless pkg?
                @log "SPM Discovered a new package #{pinfo.name}"
                spkg = new StormPackage null, pinfo
                spkg.data.status = {}
                @packages.add spkg.id, spkg

        @packages.on 'added', (pkginfo) =>
            return unless pkginfo? or pkginfo.data?
            pkg = pkginfo.data
            #@log "Package #{pkg.name} of type #{pkg.type} and source #{pkg.source} just added into Registry"
            # Package is added into DB, include the plugin if its not builtin
            if pkg.type is "npm" and /npm:/.test(pkg.source)
                try
                    @import pkg.name
                    pkginfo.data.status.imported = true
                    pkginfo.data.status.installed = true
                catch err
                    @log "Not able to import the module #{pkg.name}"
            else
                pkginfo.data.status.installed = true

        # start monitoring the packages and processes after run time table is loaded from DB
        @packages.on 'ready', () =>
            @log "SPM started Monitoring the system for packages..."
            @spm.monitor @config.repeatInterval

        @log 'loading Storm Instance/Process Manager...'
        @processmgr = new processmgr()

        @processmgr.on "error", (error, key, pid) =>
            #when a process failed to start, what should be done?
            @log "Error while starting the process for key #{key} ", error
            entry = @instances.entries[key]
            if entry?
                entry.data.status = "error"
                entry.saved = true
                entry.monitorOn = false
                entry.data.pid = undefined
                @instances.update key, entry


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
                entry.data.status = "error"
                @log "Failed to attach for pid " , pid , "Reason is ", err

        @processmgr.on "detachError", (err, pid, key) =>
            entry = @instances.entries[key]
            if entry isnt undefined and entry?
                entry.data.status = "error"
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
                entry.data.status = "running|monitored"
                @log "process #{pid} with key #{key}  is attached"

        @instances.on "attachnMonitor", (pid, key) =>
            # need to attach and monitor it
            @log "Starting monitor on discovered pid #{pid} with key #{key}"
            @processmgr.attach pid, key
            @processmgr.monitor pid, key

        @processmgr.on "monitor", (pid, key) =>
            @log "Starting monitor on pid #{pid} with key #{key}"
            @processmgr.monitor pid, key

    install: (pinfo, callback) ->
        # check if already exists
        try
            spkg = new StormPackage null, pinfo
        catch err
            return callback new Error err

        pkg = @packages.match spkg.data
        if pkg?
            @log "Found matching package name #{pkg.name}"
            return callback pkg

        @spm.install pinfo, (pkg) =>
            return callback new Error pkg if pkg instanceof Error
            spkg.data = pkg
            spkg.data.status = {}
            spkg.data.status.installed  = true
            spkg.data.status.imported = false
            result = @packages.add spkg.id, spkg
            result.data.id = result.id
            @log 'installed the package ', result
            callback result


    uninstall: (pinfo, callback) ->

        pkg = @packages.match pinfo
        return undefined unless pkg?

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
            return callback new Error result if result instanceof Error
            @emit 'uinstalled', pkg.name, pkg.id
            @packages.remove pkg.id
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

    #----------------------------------------------------------------------------------------
    # New invoke function to handle process management for Plugins
    #----------------------------------------------------------------------------------------
    #
    # XXX - we need to handle for a case where PLUGIN is upgraded and reloaded
    #
    invoke: (service, callback) ->
        opts = service.invocation
        return callback new Error "cannot invoke a service without valid service options" unless opts?

        match = @services.get service.id
        if match?
            return callback "DUPLICATE agent.invoke called for #{service.id} from plugin!"

        # here we check to see if the requested service is already running
        try
            throw new Error "no previous server.instance provided for check" unless service.instance?
            process.kill service.instance, 0
            # XXX - here even if the pid exists, we should confirm whether this is OUR process!
            # some form of ps check?

        catch notRunning
            # here, no such process, so let's start it
            pid = @processmgr.start opts.name, opts.path, opts.args, opts.options, service.id
            return callback new Error "unable to invoke a new service via processmgr" unless pid?

        # we want to verify that this PID is running for at least "timeout" period
        #
        # The desired condition is err with duration equal or greater than specified timeout
        isRestarting = false

        @processmgr.waitpid pid, test:false, timeout:500, (err,duration) =>
            unless err?
                return callback new Error "#{service.id} stopped running after #{duration/1000} seconds!"

            @log "#{service.id} has successfully started (or was previously running), verified running for at least #{duration/1000} seconds"
            @services.add service.id, invocation: service.invocation, instance: service.instance, running: service.isRunning

            # this should only be called ONCE for the duration of this service
            service.once 'destroy', =>
                @log "service.destroy called for #{service.id} invoked with:", service.invocation
                @processmgr.stop service.instance, service.id
                @services.remove service.id # remove my service entry

            service.on 'changed', =>
                @log "service.changed called for #{service.id} invoked with:", service.invocation
                return unless service.isRunning

                service.isRunning = false

                isRestarting = true
                @processmgr.stop service.instance, service.id
                # wait until PID DIES (checking for NOT RUNNING)
                @processmgr.waitpid service.instance, test:false, timeout:5000, (err,duration) =>
                    if err?
                        return @log "#{service.id} failed to stop in #{duration/1000} seconds... keeping things as-is"

                    @log "#{service.id} has successfully stopped, took #{duration/1000} seconds"

                    service.emit 'stopped'

                    opts = service.invocation
                    pid = @processmgr.start opts.name, opts.path, opts.args, opts.options, service.id
                    unless pid?
                        isRestarting = false
                        return @log "failed to handle service.change, unable to start!"
                    @processmgr.waitpid pid, test:false, timeout:500, (err,duration) =>
                        # we WANT an err here with timeout to indicate successful pid running
                        isRestarting = false
                        unless err?
                            return @log "service did not start successfully after service.change!"
                        service.emit 'running', pid

            service.emit 'running', pid
            callback null, pid

            # now that we've kicked off the new process, let's see if we need to monitor this guy
            if opts.monitor
                @log "monitor: starting to watch for #{service.id}..."
                async.whilst(
                    () -> service.isReady
                    (monitor) =>
                        @processmgr.waitpid service.instance, test:false, timeout:-1, interval:1000, (err,duration) =>
                            @log "monitor: #{service.id} stopped running after #{duration/1000} seconds!"
                            if isRestarting
                                @log "monitor: ignoring since the process is in the process of re-starting, going back to monitoring..."
                                setTimeout monitor, 1000
                                return

                            service.emit 'stopped'
                            opts = service.invocation
                            @log "monitor: #{service.id} attempting to restart!"
                            pid = @processmgr.start opts.name, opts.path, opts.args, opts.options, service.id
                            @processmgr.waitpid pid, test:false, timeout:500, (err,duration) =>
                                # we WANT an err here with timeout to indicate successful pid running
                                unless err?
                                    throw new Error "service did not start successfully after monitor's attempt at a restart!"
                                service.emit 'running', pid
                                setTimeout monitor, 1000
                    (err) =>
                        @log "monitor: #{service.id} service is no longer being monitored!"
                )
                #@processmgr.attach  pid, service.id
                #@processmgr.monitor pid, service.id

    #----------------------------------------------------------------------------------------

    start: (key, callback) ->
        entry = @instances.entries[key]
        return callback new Error "Key #{key} does not exist in DB" unless entry? and entry.data?
        #@log "Environment options to start the process : ", entry.data.options
        pid = @processmgr.start entry.data.name, entry.data.path, entry.data.args, entry.data.options, key
        return callback new Error "Not able to start the binary" unless pid?
        entry.data.pid = pid
        entry.monitorOn = true  if entry.data.monitor is true
        entry.saved = true
        @instances.update key, entry
        @processmgr.attach pid, key if entry.data.monitor is true
        callback key, pid if callback?
        @processmgr.emit "monitor", pid, key if entry.monitorOn is true


    stop: (key, callback) ->
        entry = @instances.entries[key]
        return callback new Error "No running process" unless entry? and entry.data? and entry.data.pid?
        @log "Stopping the process with pid #{entry.data.pid}"
        entry.monitorOn = false
        entry.saved = true
        @instances.update key, entry
        return @processmgr.stop entry.data.pid, key

    restart: (key, callback) ->
        entry = @instances.entries[key]
        entry.monitorOn = false
        status = @processmgr.stop entry.data.pid, key
        unless status instanceof Error
            async.series [(next) =>
                setTimeout next, 1000

            ], () =>
                entry.data.options.env.LD_LIBRARY_PATH = '/lib:/usr/lib'
                #@log "Environment options to restart the process : ", entry.data.options
                pid = @processmgr.start entry.data.name, entry.data.path, entry.data.args, entry.data.options, key
                entry.data.pid = pid
                entry.monitorOn = true if entry.data.monitor is true
                entry.saved = true
                @instances.update key, entry
                @processmgr.attach pid, key if entry.data.monitor is true
                callback key,pid if callback?
                @processmgr.emit "monitor", pid, key if entry.monitorOn is true


    newInstance: (body) ->
        try
            new StormInstance body
        catch err
            return new Error err

###
# SINGLETON CLASS OBJECT
###
module.exports.StormFlash = StormFlash
module.exports.StormInstance = StormInstance
module.exports.StormPackage = StormPackage


#-------------------------------------------------------------------------------------------

if require.main is module

    config = null
    storm = null # override during dev
    agent = new StormFlash config

    agent.run storm

    process.on 'uncaughtException' , (err) =>
        agent.log "Caught an exception with backtrace", err.stack

