Array::unique = ->
  output = {}
  output[@[key]] = @[key] for key in [0...@length]
  value for key, value of output

class CloudFlash

    validate = require('json-schema').validate
    uuid = require('node-uuid')
    exec = require('child_process').exec
    fs = require 'fs'
    path = require 'path'
    fileops = require 'fileops'
    
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
        @db = require('dirty') '/tmp/cloudflash.db'        
        @db.on 'load', ->
            console.log 'loaded cloudflash.db'
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
    ## To restart nodemon simplly update or create a file in cloudflash directory
    '''
    restartNode: (cloudflashModule) ->
        result = ''
        filename = "/lib/node_modules/cloudflash/lib/restartnode.coffee"        
        cloudflashModule = cloudflashModule.unique()
        console.log ' array: ' + cloudflashModule
        for module in cloudflashModule
            result += module
        console.log 'result: ' + result         
        fileops.createFile filename, (result) =>
            return new Error "Unable to restart node!" if result instanceof Error
            fileops.updateFile filename, result
    '''
    ## To include modules in DB to zappa server
    includeModules: (cloudflashModule) ->
        cloudflashModule = cloudflashModule.unique()
        if cloudflashModule.length > 0
            for module in cloudflashModule
                console.log "include /lib/node_modules/#{module}"
                @include require "/lib/node_modules/#{module}"
        
    ##
    # ADD/REMOVE special higher-order routines that performs DB record keeping
    # If cloudflash modules sub-directory exist while nodemon started on re-installaing module nodemon restarts.
    # when new module is installed via cloudflash controller / new sub directory created under /lib/nodemodules after nodemon started,
    # nodemon doesnt re-starts 
   
    add: (module,entry, type, callback) ->
        # 1. check if component already included in DB, if so, we skip including...
        exists = 0; cloudflashModule = []; exists = {}
        
        @db.forEach (key,val) ->
            if val && type == true && val.description.name == module.description.name then exists = 1                           
            cloudflashModule.push val.description.name if val

        console.log 'cloudflashModule: '+ cloudflashModule
        if type == true && exists == 1           
            return callback new Error "#{module.description.name} module already included try updating module!"
        
        if type == false
            if module.description.version && entry.description.version 
                if module.description.version == entry.description.version
                    return callback new Error "#{module.description.name} module no change in version!"      
                 
                        
        @check module.description, (error) =>
            unless error instanceof Error
                cloudflashModule.push module.description.name
                '''                               
                if type == true
                    @restartNode cloudflashModule
                '''
                @includeModules cloudflashModule                
                # 2. add module into cloudflash
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
       
                   
    remove: (module, callback) ->
        desc = module.description
        cloudflashModule = []
        @db.forEach (key,val) ->
            if val && key != module.id                                       
                cloudflashModule.push val.description.name
        console.log 'cloudflashModule in DEL: '+ cloudflashModule                
        @db.rm module.id, =>
            @includeModules cloudflashModule
            console.log "removed module ID: #{module.id}"
            callback()
            
##
# SINGLETON CLASS OBJECT
module.exports = CloudFlash
