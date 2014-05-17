Array::unique = ->
  output = {}
  output[@[key]] = @[key] for key in [0...@length]
  value for key, value of output

StormBolt = require 'stormbolt'

class StormFlash extends StormBolt

    validate = require('json-schema').validate
    uuid = require('node-uuid')
    exec = require('child_process').exec
    fs = require 'fs'
    path = require 'path'

    schema =
        name: "module"
        type: "object"
        additionalProperties: false
        properties:
            class:    { type: "string" }
            id:       { type: "string" }
            description:
                type: "object"
                required: true
                additionalProperties: false
                properties:
                    name:      { type: "string", "required": true }
                    version:   { type: "string", "required": true }
            status:
                type: "object"
                required: false
                additionalProperties: false
                properties:
                    installed:   { type: "boolean" }
                    initialized: { type: "boolean" }
                    enabled:     { type: "boolean" }
                    running:     { type: "boolean" }
                    result:      { type: "string"  }

    constructor: (config) ->
        super config

        # key routine to import itself into agent base
        @import module

        @packages = {}
        @instances = {}

        @on 'installed', (pkg) =>
            if pkg? and pkg instanceof StormPackage
                unless pkg.id?
                    pkg.id = uuid.v4()
                    @db.set pkg.id, JSON.stringify pkg, =>
                        @emit 'changed'
                @import pkg.name if pkg.npm
                @packages[pkg.id] = pkg
                @log "[#{pkg.name}] is currently installed as:", pkg

        @on 'removed', (pkg) =>
            if pkg? and pkg instanceof StormPackage
                delete @packages[pkg.id] if pkg.id?
                @emit 'changed'

        @spm = require('./spm')
        @spm.on 'installed', (pkg) =>


        processlib = require('./processlib')
        @processmgr = new processlib()

        @newdb "#{@config.datadir}/stormflash.db", (err,@pkgdb) =>
            return unless pkgdb

            @pkgdb.on 'load', (count) =>
                @log 'loaded stormflash.db'
                try
                    @pkgdb.forEach (key,val) =>
                        console.log 'found ' + key if val
                        @emit 'installed', JSON.parse val
                catch err
                    @log err

    status: ->
        state = super
        state.packages = @packages
        state.instances = @pmgr.instances()
        state

    run: (config) ->

        if config?
            @log 'run called with:', config
            res = validate config, schema
            @log 'run - validation of runtime config:', res
            @config = extend(@config, config) if res.valid

        # start the parent bolt and agent web api instance...
        super config

        # start monitoring the packages and processes

        async.whilst(
            () ->
                @state.running

            (repeat) =>
                # inspect all packages retrieved from SPM and discover newly 'installed' packages
                for pkg in @spm.packages()
                    do (pkg) => # issue all checks in parallel
                        unless @check pkg
                            @emit 'installed', pkg

                # inspect all packages currently known to agent and discover newly 'removed' packages
                for key, pkg of @packages
                    unless @spm.exists pkg
                        @emit 'removed', pkg

                setTimeout repeat, @repeatDelay

            (err) =>
                @log "package monitoring stopped..."

    install: (pinfo, callback) ->
        # 1. check if component already installed according to DB, if so, we skip including...

        # check if already exists
        pkg = @spm.packages pinfo
        if pkg?
            return callback pkg

        @spm.install pinfo, (pkg) =>
            # should return something other than 500...
            return callback 500 if pkg instanceof Error
            if pkg.npm
                @import pkg.name
            @emit 'installed', pkg
            callback pkg

    remove: (pinfo, callback) ->
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

    validate: (module) ->
        console.log 'performing schema validation on module description'
        return validate module, schema.properties.description

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
