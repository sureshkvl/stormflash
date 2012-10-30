class CloudFlash

    validate = require('json-schema').validate
    uuid = require('node-uuid')
    exec = require('child_process').exec
    webreq = require 'request'
    fs = require 'fs'
    path = require 'path'

    schema =
        name: "module"
        type: "object"
        additionalProperties: false
        properties:
            class:    { type: "string" }
            id:       { type: "string" }
            api:      { type: "string" }
            description:
                type: "object"
                required: true
                additionalProperties: false
                properties:
                    id:     {"type": "string"}
                    name:   {"type": "string", "required": true}
                    family: {"type": "string", "required": true}
                    version:{"type": "string", "required": true}
                    pkgurl: {"type": "string", "required": true}
                    api: {"type": "string", "required": true}
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
        console.log "include is " + @include
        @db = require('dirty') '/tmp/cloudflash.db'
        @db.on 'load', ->
            console.log 'loaded cloudflash.db'
            @forEach (key,val) ->
                console.log 'found ' + key

    new: (desc) ->
        module = {}
        module.id = uuid.v4()
        module.description = desc
        module.description.id ?= uuid.v4()

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
        console.log "checking if the package '#{desc.name}' has already been installed..."
        exec "dpkg -l #{desc.name} | grep #{desc.name}", (error, stdout, stderr) =>
            callback error

    install: (module, callback) ->
        desc = module.description
        # let's download this file from the web
        filename = "/tmp/#{module.id}.pkg"
        webreq(desc.pkgurl, (error, response, body) =>
            # 1. verify that file has been downloaded
            # 2. dpkg -i filename
            # 3. verify that package has been installed
            # 4. XXX - figure out the API endpoint dynamically
            # 5. return success message back
            return callback new Error "Unable to download module package! Error was: #{error}" if error?

            console.log "checking for module package at #{filename}"
            if path.existsSync filename
                console.log 'found module package, issuing dpkg -i'
                exec "dpkg -i -F depends #{filename}", (error, stdout, stderr) =>
                #exec "echo #{filename}", (error, stdout, stderr) =>
                    return callback new Error "Unable to install module package!" if error

                    console.log "verifying that the package has been installed as #{desc.name}"
                    exec "dpkg -l #{desc.name}", (error, stdout, stderr) =>
                        return callback new Error "Unable to verify module package installation!" if error
                        callback()
            else
                return callback new Error "Unable to download and install module package!"
            ).pipe(fs.createWriteStream(filename))

    add: (module, callback) ->
        # 1. check if package already installed, if so, we we skip download...
        @check module, (error) =>
            unless error
                #openvpn is builtin and dpkg reports installed but APIs are not yet installed.
                #This step repeates for every module post but there is no harm in including again for this execption.
                @include "./node_modules/#{module.description.name}/#{module.description.api}" unless server.description == 'openvpn'
                module.status = { installed: true }
                @db.set module.id, module, ->
                    callback()
            else
                # 2. install module
                @install module, (error) =>
                    unless error
                        # 3. include module API module
                        @include "./node_modules/#{module.description.name}/#{module.description.api}"

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

            console.log "removing the module package: dpkg -r #{desc.name}"
            exec "dpkg -r #{desc.name}", (error, stdout, stderr) =>
                return @next new Error "Unable to remove module package '#{desc.name}': #{stderr}" if error
                @db.rm module.id, =>
                    console.log "removed module ID: #{module.id}"
                    callback()



##
# SINGLETON CLASS OBJECT
module.exports = CloudFlash
