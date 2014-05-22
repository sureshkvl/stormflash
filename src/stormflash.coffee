Array::unique = ->
  output = {}
  output[@[key]] = @[key] for key in [0...@length]
  value for key, value of output

StormData = require('stormagent').StormData

class StormInstance extends StormData

    schema =
        name: "instance"
        type: "object"
        required: true
        properties:
            name : { type: "string", "required": true }
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

StormRegistry = require('stormagent').StormRegistry

class StormInstances extends StormRegistry
    constructor: (filename) ->
        @on 'load', (key,val) ->
            entry = new StormInstance key,val
            if entry?
                entry.saved = true
                @add key, entry

        @on 'removed', (key) ->
            # an entry is removed in Registry

        processmgr = require('./processmgr').ProcessManager
        @processmgr = new processmgr()
        @processmgr.on "started", (key, pid) ->
            entry = @entries[key]
            return unless entry?
            entry.data.pid = pid
            entry.status = "running"
            @update key, entry.data
            @processmgr.attach pid

        @processmgr.on "error", (error, key, pid) ->
            #when a process failed to start, what should be done?
            @log "Error while starting the process", error
            entry.status = "error"

        @processmgr.on "signal", (signal, pid, key) ->
            switch signal
                when "stopped", "killed", "exited"
                    entry = @entries[key]
                    if entry isnt null and entry.data.monitor is true
                        # process sent signal 
                        @processmgr.sendisgnal pid, SIGKILL
                        @processmgr.start

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

        @processmgr.on "stopped", (signal, key, pid) ->
            # restart the process if entry has monitor option set
            # if stopped gracefully dont start it again
            entry = @entries[key]
            @log "process stopped due to signal ", signal
            if signal is not "graceful"
                @processmgr.start  entry.name, entry.path, entry.args, entry.pid, key if entry isnt null

        @processmgr.on "attached", (err, pid, key, result) ->
            return if err?
            entry = @entries[key]
            if entry isnt null
                entry.status = "running|monitored"
                # Now start monitoring it
                @emit "monitor", pid, key

        @processmgr.on "monitor", (pid, key) ->
            @processmgr.monitor pid, key

        @processmgr.on "detached", (pid) ->
            entry = @entries[key]
            if entry isnt null
                entry.status = "running"


        super filename

    # get storminstance details
    get: (key) ->
        entry = super key
        return unless entry?
        entry.data.id = entry.id
        entry.data


    add: (key, val) ->
        if key isnt null  and val isnt null
            super key, val
            # Start the instance with provided arguments
            @processmgr.start entry.name, entry.path, entry.args, entry.pid, key  if entry isnt null


    remove: (key) ->
        # Set monitoring to false and stop from the process
        entry = @entries[key]
        if entry isnt null
            entry.monitor = false
            @processmgr.stop entry.pid, key
            super key

    monitor: ->
        # Monitor all the instances 
        @entries.forEach (key, value) ->
            @processmgr.attach value.data.pid  if value.data.monitor is true

        #Now run the process manager
        @processmgr.run()

#-----------------------------------------------------------------

class StormPackage  extends StormData
    schema =
        name: "package"
        type: "object"
        required: true
        properties:
            name : { type: "string", "required": true }
            version : { type: "string", "required": true }
            source : { type: "string", "required": true }

    constructor: (id, data) ->
        super id, data, schema
        @installer = undefined

#--------------------------------------------------------------------

class StormPackages extends StormRegistry
    constructor: (filename) ->
        @on 'load', (key,val) ->
            entry = new StormInstance key,val
            if entry?
                entry.saved = true
                @add key, entry

        @on 'removed', (key) ->
            # an entry is removed in Registry

        

#--------------------------------------------------------------------
StormBolt = require 'stormbolt'

class StormFlash extends StormBolt

    validate = require('json-schema').validate
    exec = require('child_process').exec
    fs = require 'fs'
    path = require 'path'

    constructor: (config) ->
        super config

        # key routine to import itself into agent base
        @import module

        @packages  = new StormPackages  "#{@config.datadir}/packages.db"
        @instances = new StormInstances "#{@config.datadir}/instances.db"


    status: ->
        state = super
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

        # start the parent bolt and agent web api instance...
        super config

        # start monitoring the packages and processes
        #@packages.monitor  @config.repeatdelay
        #@instances.monitor @config.repeatdelay

    install: (pinfo, callback) ->
        # 1. check if component already installed according to DB, if so, we skip including...

        # check if already exists
        pkg = @packages.match pinfo
        if pkg?
            return callback pkg

        @spm.install pinfo, (pkg) =>
            # should return something other than 500...
            return callback 500 if pkg instanceof Error
            if pkg.npm
                @import pkg.name
            @emit 'installed', pkg
            callback pkg

    uninstall: (pinfo, callback) ->
        stormflashModule = []; exists = 0
        fs.existsSync "/lib/node_modules/#{module.description.name}", (exists) ->
            if exists
                # Return 304 status when module already exist
                return callback({result:304})
            else
                @db.forEach (key,val) ->
                    if val && key != module.id
                        stormflashModule.push val.description.name
                console.log 'stormflashModule in DEL: '+ stormflashModule
                @db.rm module.id, =>
                    @includeModules stormflashModule
                    console.log "removed module ID: #{module.id}"
                    callback({result:200})

    getCommand: (installer, command, target, version) ->
        append = ''
        switch "#{installer}.#{command}"
            when "npm.check"
                append = "@#{version}" if version?
                return "cd /lib; npm ls 2>/dev/null | grep #{target}#{append}"
            else
                console.log new Error "invalid command #{installer}.#{command} for #{target}!"
                return null

    check: (component, callback) ->
        console.log "checking if the component '#{component.name}' has already been installed using npm..."

        command = @getCommand 'npm', "check", component.name, component.version
        @execute command, (error) =>
            unless error
                console.log "#{component.name} is already installed"
                callback true
            else
                callback error

    update: (module,entry, callback) ->
        if module.id
            @add module,entry, false, (res) =>
                unless res instanceof Error
                    callback res
                else
                    callback res
        else
            callback new Error "Could not find ID! #{id}"

    ## check for module in /lib/node_modules/module-name directory
    #To remove module-id from DB


##
# SINGLETON CLASS OBJECT
module.exports = StormFlash

# instance = null
# module.exports = (args) ->
#     if not instance?
#         instance = new StormAgent args
#     return instance
