class CloudFlash

    validate = require('json-schema').validate
    uuid = require('node-uuid')
    exec = require('child_process').exec
    webreq = require 'request'
    fs = require 'fs'
    path = require 'path'

    schema =
        name: "service"
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
        service = {}
        service.id = uuid.v4()
        service.description = desc
        service.description.id ?= uuid.v4()

        return service

    lookup: (id) ->
        console.log "looking up service ID: #{id}"
        entry = @db.get id
        if entry

            if schema?
                console.log 'performing schema validation on retrieved service entry'
                result = validate entry, schema
                console.log result
                return new Error "Invalid service retrieved: #{result.errors}" unless result.valid

            return entry
        else
            return new Error "No such service ID: #{id}"

    list: ->
        res = { 'services': [] }
        @db.forEach (key,val) ->
            console.log 'found ' + key
            res.services.push val
        console.log 'listing...'
        return res

    validate: (service) ->
        console.log 'performing schema validation on service description'
        return validate service, schema.properties.description


    ##
    # ASYNC ROUTINES

    check: (service, callback) ->
        desc = service.description
        console.log "checking if the package '#{desc.name}' has already been installed..."
        exec "dpkg -l #{desc.name} | grep #{desc.name}", (error, stdout, stderr) =>
            callback error

    install: (service, callback) ->
        desc = service.description
        # let's download this file from the web
        filename = "/tmp/#{service.id}.pkg"
        webreq(desc.pkgurl, (error, response, body) =>
            # 1. verify that file has been downloaded
            # 2. dpkg -i filename
            # 3. verify that package has been installed
            # 4. XXX - figure out the API endpoint dynamically
            # 5. return success message back
            return callback new Error "Unable to download service package! Error was: #{error}" if error?

            console.log "checking for service package at #{filename}"
            if path.existsSync filename
                console.log 'found service package, issuing dpkg -i'
                exec "dpkg -i -F depends #{filename}", (error, stdout, stderr) =>
                #exec "echo #{filename}", (error, stdout, stderr) =>
                    return callback new Error "Unable to install service package!" if error

                    console.log "verifying that the package has been installed as #{desc.name}"
                    exec "dpkg -l #{desc.name}", (error, stdout, stderr) =>
                        return callback new Error "Unable to verify service package installation!" if error
                        callback()
            else
                return callback new Error "Unable to download and install service package!"
            ).pipe(fs.createWriteStream(filename))

    add: (service, callback) ->
        # 1. check if package already installed, if so, we we skip download...
        @check service, (error) =>
            unless error
                #openvpn is builtin and dpkg reports installed but APIs are not yet installed.
                #This step repeates for every service post but there is no harm in including again for this execption.
                @include "./node_modules/#{service.description.name}/#{service.description.api}" unless server.description == 'openvpn'
                service.status = { installed: true }
                @db.set service.id, service, ->
                    callback()
            else
                # 2. install service
                @install service, (error) =>
                    unless error
                        # 3. include service API module
                        @include "./node_modules/#{service.description.name}/#{service.description.api}"

                        # 4. add service into cloudflash
                        service.status = { installed: true }
                        @db.set service.id, service, ->
                            callback()
                    else
                        callback error

    remove: (service, callback) ->
        desc = service.description

        @check service, (error) =>
            return callback new Error "Unable to verify service package installation!" if error

            console.log "removing the service package: dpkg -r #{desc.name}"
            exec "dpkg -r #{desc.name}", (error, stdout, stderr) =>
                return @next new Error "Unable to remove service package '#{desc.name}': #{stderr}" if error
                @db.rm service.id, =>
                    console.log "removed service ID: #{service.id}"
                    callback()



##
# SINGLETON CLASS OBJECT
module.exports = CloudFlash
