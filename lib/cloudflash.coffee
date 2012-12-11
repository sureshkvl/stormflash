class PackageManager

    uuid = require('node-uuid')
    webreq = require 'request'
    fs = require 'fs'
    path = require 'path'
    constructor: (@include) ->
        @db = require('dirty') '/tmp/cloudflash-components.db'
        @db.on 'load', ->
            console.log 'loaded cloudflash-components.db'
            @forEach (key,val) ->
                console.log 'found ' + key

    getCommand: (installer, command, target) ->
        switch "#{installer}.#{command}"
            when "dpkg.check", "apt-get.check"
                return "dpkg -l #{target} | grep #{target}"
            when "dpkg.install"
                return "dpkg -i #{target}"
            when "dpkg.uninstall"
                return "dpkg -r #{target}"

            when "rpm.install"
                return "rpm -ivh #{target}"
            when "rpm.uninstall"
                return "rpm -r #{target}"

            when "npm.install"
                return "npm install -g #{target} --prefix=/; ls -l /lib/node_modules/#{target}"
            when "npm.uninstall"
                return "npm remove -g #{target} --prefix=/"
            when "npm.check"
                return "ls -l /lib/node_modules/#{target}"

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

    check: (component, callback) ->
        console.log "checking if the component '#{component.name}' has already been installed using #{component.installer}..."

        command = @getCommand component.installer, "check", component.name
        @execute command, (error) =>
            unless error
                console.log "#{component.name} is already installed"
                callback true
            else
                console.log error
                callback false

    download: (url, filename, callback) ->
        console.log "downloading #{url} to #{filename}..."
        webreq(url, (error, response, body) =>
            if error or not path.existsSync filename
                callback new Error "Unable to download component! #{url} Error was: #{error}"
            else
                callback()

        ).pipe(fs.createWriteStream(filename))

    install: (component, callback) =>

        if component.url
            filename = "/tmp/" + uuid.v4() + ".pkg"
            @download component.url, filename, (error) =>
                return callback error if error

                command = @getCommand component.installer, "install", filename
                @execute command, (error) =>
                    return callback new Error "Unable to install #{component.name} due to #{error}!" if error

                    # verify installation and return result
                    @check component, (exists) ->
                        if exists
                            console.log "Package #{component.name} is successfully installed"
                            callback()
                        else
                            callback new Error "Unable to verify component installation!"

    uninstall: (component, callback) ->
        console.log "uninstalling #{component.name} using #{component.installer}..."
        command = @getCommand component.installer, "uninstall", component.name
        @execute command, (error) =>
            unless error
                console.log "#{component.name} has been successfully uninstalled."
                callback()
            else
                console.log error
                callback new Error "#{component.name} failed to uninstall!"

    ##
    # make a unique id for the component
    uid: (component) ->
        switch component.installer
            when "dpkg","apt-get"
                return "deb://#{component.name}"

            when "rpm","yum"
                return "rpm://#{component.name}"

            when "npm"
                return "npm://#{component.name}"

            else
                return null

    ##
    # ADD/REMOVE special higher-order routines that performs DB record keeping

    add: (component, callback) ->
        @check component, (exists) =>
            id = @uid component
            if exists
                record = @db.get id
                unless record
                    # in the event that system already has it pre-installed
                    record = component
                    record.persist = true
                record.depends++
                @db.set id, record, ->
                    callback()
            else
                @install component, (error) =>
                    return callback error if error

                    component.status = { installed: true }
                    component.depends = 1
                    @db.set id, component, ->
                        callback()

    remove: (component, callback) ->
        @check component, (exists) =>
            return callback() unless exists

            id = @uid component
            record = @db.get id
            record.depends--
            if record.depends > 0 or record.persist
                @db.set id, record, ->
                    callback()
            else
                @uninstall component, (error) =>
                    unless error
                        @db.rm id, ->
                            callback()
                    else
                        callback error


class CloudFlash

    validate = require('json-schema').validate
    uuid = require('node-uuid')
    exec = require('child_process').exec
    fs = require 'fs'
    path = require 'path'
    async = require 'async'

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
                    installer: { type: "string", "required": true }
                    version:   { type: "string" }
                    url:       { type: "string" }
                    dependencies:
                        items:
                            type: "object"
                            additionalProperties: false
                            properties:
                                name:      { type: "string", "required": true }
                                installer: { type: "string", "required": true }
                                version:   { type: "string" }
                                url:       { type: "string" }
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
                console.log 'found ' + key
        @pkgmgr = new PackageManager

    new: (desc) ->
        module = {}
        module.id = uuid.v4()
        module.description = desc
        module.description.dependencies ?= []

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

    list: ->
        res = { 'modules': [] }
        @db.forEach (key,val) ->
            console.log 'found ' + key
            res.modules.push val
        console.log 'listing...'
        return res

    validate: (module) ->
        console.log 'performing schema validation on module description'
        return validate module, schema.properties.description


    ##
    # ASYNC ROUTINES

    check: (module, callback) ->
        desc = module.description
        console.log "checking if the module '#{desc.name}' has already been installed..."
        @pkgmgr.check desc, (exists) ->
            unless exists
                callback new Error "component #{desc.name} not installed"
            else
                callback()

    install: (module, callback) ->
        desc = module.description

        mapinstall = (item, callback) =>
            @pkgmgr.add item, (error) ->
                unless error
                    callback null, item
                else
                    callback error, null

        checkPackage = (item, callback) =>
            @pkgmgr.check item, (exists) ->
                if exists
                    callback true
                else
                    callback false

        filterPackages = (item, callback) ->
            if item==null
                callback true
            else
                callback false


        # first filter out dependencies already installed
        async.reject desc.dependencies, checkPackage, (toInstallList) =>
            console.log "after reject to installist ",  toInstallList
            # now have list of components that need to be installed
            # but we run through install on ALL dependencies
            async.mapSeries toInstallList , @pkgmgr.install, (error, results) =>
                unless error
                    # 2. install the primary module via NPM
                    exec "npm install -g #{desc.name} --prefix=/; ls -l /lib/node_modules/#{desc.name}" , (error, stdout, stderr) =>
                        unless error
                            console.log "Done installing modules #{desc.name}"
                            callback()
                        else
                            callback error
                        
                else
                    console.log "List of components failed " + results
                    # if here, something went wrong, find those that were installed and remove them
                    async.filter results, filterPackages, (components) =>
                        async.forEach components, @pkgmgr.remove, (error) ->
                        callback error


    ##
    # ADD/REMOVE special higher-order routines that performs DB record keeping

    add: (module, callback) ->
        # 1. check if component already installed, if so, we we skip download...
        @check module, (error) =>
            unless error
                module.status = { installed: true }
                @db.set module.id, module, ->
                    callback()
            else
                # 2. install module
                @install module, (error) =>
                    unless error
                        # 3. include API module
                        try
                            @include require "/lib/node_modules/#{module.description.name}"
                            # 4. add module into cloudflash
                            module.status = { installed: true }
                            @db.set module.id, module, ->
                                callback()
                        catch err
                            exec "npm remove -g #{module.description.name} --prefix=/"
                            err = new Error "Unable to include the module #{module.description.name}"
                            console.log err
                            callback err

                    else
                        callback error

    remove: (module, callback) ->
        desc = module.description

        @check module, (error) =>
            return callback new Error "Unable to verify module component installation!" if error

            # remove all dependencies
            #
            console.log "removing the module component: dpkg -r #{desc.name}"
            exec "dpkg -r #{desc.name}", (error, stdout, stderr) =>
                return @next new Error "Unable to remove module component '#{desc.name}': #{stderr}" if error
                @db.rm module.id, =>
                    console.log "removed module ID: #{module.id}"
                    callback()

##
# SINGLETON CLASS OBJECT
module.exports = CloudFlash
