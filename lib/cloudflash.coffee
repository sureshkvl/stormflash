class PackageManager

    constructor: (@include) ->
        @db = require('dirty') '/tmp/cloudflash-packages.db'
        @db.on 'load', ->
            console.log 'loaded cloudflash-packages.db'
            @forEach (key,val) ->
                console.log 'found ' + key

    getCommand: (installer, command, target) ->
        switch "#{installer}.#{command}"
            when "dpkg.check", "apt-get.check"
                return "dpkg -l #{target} | grep #{target}"
            when "dpkg.install"
                return "dpkg -i -F depends #{target}"
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

            else
                console.log new Error "invalid command #{installer}.#{command} for #{target}!"
                return null

    execute: (command, callback) ->
        unless command
            return callback new Error "no valid command for execution!"

        console.log "executing #{command}..."
        exec command, (error, stdout, stderr) =>
            if error
                callback error
            else
                callback()

    check: (package, callback) ->
        console.log "checking if the package '#{package.name}' has already been installed using #{package.installer}..."

        command = @getCommand package.installer, "check", package.name
        @execute command, (error) =>
            unless error
                console.log "#{package.name} is already installed"
                callback true
            else
                console.log error
                callback false

    install: (package, callback) ->

        if package.url
            filename = "/tmp/" + uuid.v4() + ".pkg"
            @download package.url, filename, (error) =>
                return callback error if error

                command = @getCommand package.installer, "install", filename
                @execute command, (error) =>
                    return callback new Error "Unable to install #{package.name} due to #{error}!" if error

                    # verify installation and return result
                    @check package, (exists) ->
                        if exists
                            console.log "Package #{package.name} is successfully installed"
                            callback()
                        else
                            callback new Error "Unable to verify package installation!"

    download: (url, filename, callback)
        console.log "downloading #{url} to #{filename}..."
        webreq(url, (error, response, body) =>
            if error or not path.existsSync filename
                callback new Error "Unable to download package! #{url} Error was: #{error}"
            else
                callback()

        ).pipe(fs.createWriteStream(filename))

    uninstall: (package, callback) ->
        console.log "uninstalling #{package.name} using #{package.installer}..."
        command = @getCommand package.installer, "uninstall", package.name
        @execute command, (error) =>
            unless error
                console.log "#{package.name} has been successfully uninstalled."
                callback()
            else
                console.log error
                callback new Error "#{package.name} failed to uninstall!"

    ##
    # make a unique id for the package
    uid: (package) ->
        switch package.installer
            when "dpkg","apt-get"
                return "deb://#{package.name}"

            when "rpm","yum"
                return "rpm://#{package.name}"

            when "npm"
                return "npm://#{package.name}"

            else
                return null

    ##
    # ADD/REMOVE special higher-order routines that performs DB record keeping

    add: (package, callback) ->
        @check package, (exists) =>
            id = @uid package
            if exists
                record = @db.get id
                unless record
                    # in the event that system already has it pre-installed
                    record = package
                    record.persist = true
                record.depends++
                @db.set id, record, ->
                    callback()
            else
                @install package, (error) =>
                    return callback error if error

                    package.status = { installed: true }
                    package.depends = 1
                    @db.set id, package, ->
                        callback()

    remove: (package, callback) ->
        @check package, (exists) =>
            return callback() unless exists

            id = @uid package
            record = @db.get id
            record.depends--
            if record.depends > 0 or record.persist
                @db.set id, record, ->
                    callback()
            else
                @uninstall package, (error) =>
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
                callback new Error "package #{desc.name} not installed"
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

        async.mapSeries desc.dependencies, mapinstall, (error, results) ->
            unless error
                # install the primary module
                #
            else
                pkgmgr.remove

        # first filter out dependencies already installed
        async.reject desc.dependencies, pkgmgr.check, (toinstall) ->
            # now have list of packages that need to be installed
            # but we run through install on ALL dependencies
            async.forEachSeries desc.dependencies, pkgmgr.install, (error) ->
                unless error
                    # 2. install the primary module via NPM


                # if here, something went wrong, find those that were installed and remove them
                async.filter toinstall, pkgmgr.check, (toremove) ->
                    async.forEach toremove, pkgmgr.remove, (error) ->
                        callback error

    ##
    # ADD/REMOVE special higher-order routines that performs DB record keeping

    add: (module, callback) ->
        # 1. check if package already installed, if so, we we skip download...
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
                        @include require "/lib/node_modules/#{module.description.name}"

                        # 4. add module into cloudflash
                        module.status = { installed: true }
                        @db.set module.id, module, ->
                            callback()
                    else
                        callback error

    remove: (module, callback) ->
        desc = module.description

        @check module, (error) =>
            return callback new Error "Unable to verify module package installation!" if error

            # remove all dependencies
            #
            console.log "removing the module package: dpkg -r #{desc.name}"
            exec "dpkg -r #{desc.name}", (error, stdout, stderr) =>
                return @next new Error "Unable to remove module package '#{desc.name}': #{stderr}" if error
                @db.rm module.id, =>
                    console.log "removed module ID: #{module.id}"
                    callback()

##
# SINGLETON CLASS OBJECT
module.exports = CloudFlash
