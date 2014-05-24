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
            monitor: { type: "boolean", "required" : false}
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
                @emit 'instanceloaded', key, val

        @on 'removed', (key) ->
            # an entry is removed in Registry


        super filename

    # get storminstance details
    get: (key) ->
        entry = super key
        entry

    update: (key, val) ->
        @emit 'update', key, val.data.pid, val.data.path, val.data.args
        super key, val

    add: (key, val) ->
        entry = super key, val
        # Trigger monitor event if pid exists else start the instance with provided arguments
        if entry? and entry.data? and entry.data.pid?
            @emit "monitor", entry.data.pid, key
        entry


    remove: (key) ->
        # Set monitoring to false and stop from the process
        entry = @entries[key]
        if entry isnt null
            entry.monitor = false
            @emit 'remove', key, entry.data.pid
            super key

#-----------------------------------------------------------------

class StormPackage  extends StormData
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
            @log "Dumping entry",entry.key, entry.value
            if (entry.data.name is pinfo.name) and (entry.data.version is pinfo.version) and (entry.data.source is pinfo.source)
                @log "Matching entry found ", entry.data
                entry.data.id = entry.id
                return entry.data
                

    find: (name, version) ->
        for key of @entries
            entry = @entries[key]
            if (entry.data.name is name) and (entry.data.version is version)
                entry.data.id = entry.id
                entry.data


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

        spm = require('./spm').StormPackageManager
        @spm = new spm()
        @spm.on 'discover', (pinfo) ->
            pkg = @packages.find pinfo.name pinfo.version
            unless pkg?
                @packages.add uuid.v4(), pinfo


        processmgr = require('./processmgr').ProcessManager
        @processmgr = new processmgr()

        @processmgr.on "error", (error, key, pid) ->
            #when a process failed to start, what should be done?
            @log "Error while starting the process for key #{key} ", error
            entry.status = "error"

        @processmgr.on "signal", (signal, pid, key) ->
            switch signal
                when "stopped", "killed", "exited"
                    entry = @entries[key]
                    if entry isnt null and entry.data.monitorOn is true
                        # process sent signal 
                        @processmgr.start entry.name, entry.path, entry.args, entry.pid, key

        @processmgr.on "attachError", (err, pid, key) ->
            entry = @entries[key]
            if entry isnt null
                entry.status = "error"
                @log "Failed to attach for pid " , pid , "Reason is ", err

        @processmgr.on "detachError", (err, pid, key) ->
            entry = @entries[key]
            if entry isnt null
                entry.status = "error"
                @log "Failed to detach for pid " , pid , "Reason is ", err

        @processmgr.on "stopped", (signal, pid, key) ->
            # restart the process if entry has monitor option set
            # if stopped gracefully dont start it again
            @log "process stopped due to signal ", signal if signal?
            entry = @entries[key] if key?
            if entry?
                @log "process was not running. pid expected is  ", pid , "binary name is ", entry.name if entry?
                @processmgr.start  entry.name, entry.path, entry.args, entry.pid, key if entry? and entry.data.monitrOn is true

        @processmgr.on "attached", (result, pid, key) ->
            entry = @entries[key]
            if entry isnt null
                entry.status = "running|monitored"

        @processmgr.on "monitor", (pid, key) ->
            @processmgr.monitor pid, key


    status: ->
        state = {}
        state.packages  = @packages.list()
        state.instances = @instances.list()
        state

    run: (config) ->

        ###
        if config?
            @log 'run called with:', config
            res = validate config, schema
            @log 'run - validation of runtime config:', res
            @config = extend(@config, config) if res.valid
        ###

        super config


        # start monitoring the packages and processes
        @spm.monitor  @config.repeatdelay

    install: (pinfo, callback) ->
        # check if already exists
        console.log pinfo
        @log "checking for package #{pinfo.name} in DB", pinfo
        pkg = @packages.match pinfo
        console.log "pkg is ", pkg
        if pkg?
            @log "Found matching package name #{pkg.name}"
            return callback 409

        @spm.install pinfo, (pkg) =>
            # should return something other than 500...
            return callback pkg if pkg instanceof Error
            @packages.add uuid.v4(), pinfo
            @emit 'installed the package ', pinfo.name, pinfo.id
            callback pkg


    uninstall: (pinfo, callback) ->

        pkg = @packages.match pinfo
        return 404 if pkg instanceof Error
        
        # Kill the instances and clean up StormInstance Registry
        instance = @instances.match pkg.name

        if instance?
            # one time event registration to stop the process
            @processmgr.once 'stop', (key, pid) ->
                #signal the process to stop
                @processmgr.sendsignal pid, SIGHUP
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
        entry = @instances.get key
        return callback new Error "Key #{key} does not exist in DB" unless entry?
        pid = @processmgr.start entry.name, entry.path, entry.args, key
        callback new Error "Not able to start the binary" unless pid?
        entry.pid = pid
        entry.monitorOn = true  if entry.monitor is true

        @processmgr.attach pid, key
        callback key, pid


    stop: (key, callback) ->
        entry = @instances.get key
        return callback new Error "No running process" unless entry? and entry.pid?
        entry.monitorOn = false
        return @processmgr.stop entry.pid, key

    restart: (key, callback) ->
        entry = @instances.get key
        entry.monitorOn = false
        status = @processmgr.stop entry.pid, key
        unless status instanceof Error
            pid = @processmgr.start entry.name, entry.path, entry.args, key
            entry.pid = pid
            entry.monitorOn = true if entry.monitor is true





###
# SINGLETON CLASS OBJECT
###
module.exports.StormFlash = StormFlash

# instance = null
# module.exports = (args) ->
#     if not instance?
#         instance = new StormAgent args
#     return instance
