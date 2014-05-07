Array::unique = ->
  output = {}
  output[@[key]] = @[key] for key in [0...@length]
  value for key, value of output

class StormFlash

    validate = require('json-schema').validate
    uuid = require('node-uuid')
    exec = require('child_process').exec
    fs = require 'fs'
    path = require 'path'
    fileops = require 'fileops'

#    packagelist = require('./packagelib')
#    @pkglist = new packagelist()

#    processmgr = require('./processlib')
#    @processmgr = new processmgr()

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

    constructor: (@include) ->
        console.log 'stormflash constructor called'
        packagelist = require('./packagelib')
        @pkglist = new packagelist()
        processlib = require('./processlib')
        @processmgr = new processlib()
        environmentlist = require('./environmentlib')
        @environment = new environmentlist()
        @db = require('dirty') '/tmp/stormflash.db'
        @db.on 'load', ->
            console.log 'loaded stormflash.db'
            @forEach (key,val) ->
                console.log 'found ' + key if val

    new: (desc,id) ->
        module = {}
        if id
            module.id = id
        else
            module.id = uuid.v4()
        module.description = desc
        return module

    lookup: (id) ->
        console.log "looking up module ID: #{id}"
        entry = @db.get id
        if entry

            if schema?
                console.log 'performing schema validation on retrieved module entry'
                result = validate entry, schema
                console.log result
                return new Error "Invalid module retrieved: #{result.errors}" unless result.valid

            return entry
        else
            return new Error "No such module ID: #{id}"

    getCommand: (installer, command, target, version) ->
        append = ''
        switch "#{installer}.#{command}"
            when "npm.check"
                append = "@#{version}" if version?
                return "cd /lib; npm ls 2>/dev/null | grep #{target}#{append}"
            else
                console.log new Error "invalid command #{installer}.#{command} for #{target}!"
                return null

    execute: (command, callback) ->
        unless command
            return callback new Error "no valid command for execution!"

        console.log "executing #{command}..."
        exec = require('child_process').exec
        exec command, (error, stdout, stderr) =>
            if error
                callback error
            else
                callback()

    list: ->
        res = { 'modules': [] }
        @db.forEach (key,val) ->
            res.modules.push val if val
        console.log 'listing...'
        return res

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

    ## To include modules in DB to zappa server
    includeModules: (stormflashModule) ->
        stormflashModule = stormflashModule.unique()
        if stormflashModule.length > 0
            for module in stormflashModule
                console.log "include /lib/node_modules/#{module}"
                @include require "/lib/node_modules/#{module}"

    ##
    # For POST/PUT module endpoints
    # check module installed in /lib/node_modules directory with version.
    # For PUT if no change in version gives error
    # Entry added to DB is success.

    add: (module,entry, type, callback) ->
        # 1. check if component already included in DB, if so, we skip including...
        exists = 0; stormflashModule = []; exists = {}

        @db.forEach (key,val) ->
            if val && type == true && val.description.name == module.description.name then exists = 1
            stormflashModule.push val.description.name if val

        console.log 'stormflashModule: '+ stormflashModule
        if type == true && exists == 1
            # Return 304 status when module already exist
            return callback({"status": 304})

        if type == false
            if module.description.version && entry.description.version
                if module.description.version == entry.description.version
                    # Return 304 status when module and version already exist
                    return callback({"status": 304})


        @check module.description, (error) =>
            unless error instanceof Error
                stormflashModule.push module.description.name
                @includeModules stormflashModule
                # 2. add module into stormflash
                module.status = { installed: true }
                @db.set module.id, module, ->
                    callback(module)
            else
                console.log 'module check: '+ error
                return callback new Error "#{module.description.name} module not installed!"

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
    remove: (module, callback) ->
        stormflashModule = []; exists = 0
        file = fileops.fileExistsSync "/lib/node_modules/#{module.description.name}"
        unless file instanceof Error
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

    # Garbage collect every 2 sec
    # Run node with --expose-gc
    if gc?
        setInterval (
            () -> gc()
        ), 2000

##
# SINGLETON CLASS OBJECT
instance = null
module.exports = (args) ->
    if not instance?
        instance = new StormFlash args
    return instance