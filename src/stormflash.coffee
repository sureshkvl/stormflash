Array::unique = ->
  output = {}
  output[@[key]] = @[key] for key in [0...@length]
  value for key, value of output

StormData = require('stormagent').StormData

class StormPackage extends StormData

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
        # process source and find out type

    install: ->
        # do some type of check if installed in the system


class StormInstance extends StormData

    schema =
        name: "instance"
        type: "object"
        required: true
        properties:
            name : { type: "string", "required": true }
            version : { type: "string", "required": true }
            source : { type: "string", "required": true }

    constructor: (id, data) ->
        super id, data, schema

#-----------------------------------------------------------------

StormRepository = require('stormagent').StormRepository

class StormPackages extends StormRepository

    async = require 'async'

    constructor: (filename) ->
        @on 'load', (key,val) ->
            entry = new StormPackage key,val
            if entry?
                entry.saved = true
                @add key, entry

        @on 'added', (pkg) ->
            if pkg.npm
                @import pkg.name

        @on 'removed', (pkg) ->
            pkg.remove() if pkg.remove?

        #spm is the repository of system installed packages
        @spm = require('./spm')

        super filename

    get: (key) ->
        entry = super key

    add: (key, pkg) ->
        entry = super key, pkg

    match: (pdata) ->
        for key, pkg of @entries
            if pkg.data.name is pdata.name and pkg.data.version is pdata.version and pkg.data.source is pdata.source
                return key
        false

    monitor: (interval) ->
        async.whilst(
            () =>
                @running
            (repeat) =>
                # inspect all packages retrieved from SPM and discover newly 'installed' packages
                for pdata in @spm.list()
                    do (pdata) => # issue all checks in parallel
                        unless @match pdata
                            @add null, new StormPackage null, pkg

                # inspect all packages currently known to agent and discover newly 'removed' packages
                for key, pkg of @entries
                    unless pkg.installed()
                        @remove key
                    ###
                    unless @spm.exists pkg.data
                        @remove key
                    ###

                setTimeout repeat, interval

            (err) =>
                @log "package monitoring stopped..."
        )

class StormInstances extends StormRepository
    constructor: (filename) ->
        @on 'load', (key,val) ->
            entry = new StormInstance key,val
            if entry?
                entry.saved = true
                @add key, entry

        @on 'removed', (token) ->
            token.destroy() if token.destroy?

        super filename

    get: (key) ->
        entry = super key

#-----------------------------------------------------------------

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

        @on 'removed', (pkg) =>
            if pkg? and pkg instanceof StormPackage
                delete @packages[pkg.id] if pkg.id?
                @emit 'changed'

        processlib = require('./processlib')
        @processmgr = new processlib()

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
        @spm.monitor @config.repeatdelay

    install: (pkg, callback) ->
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
