class CloudFlash

    validate = require('json-schema').validate
    uuid = require('node-uuid')
    exec = require('child_process').exec
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
                    pkg:
                        items: {"type":"string"}
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
        #TODO: If the post has newer version of npm module, we need to check and install it.
        exec "ls -l /lib/node_modules | grep #{desc.name}", (error, stdout, stderr) =>
            console.log error
            callback error

    install: (service, callback) ->
        desc = service.description
        index = 0
        index = installPackages desc, service.id, index, callback

    add: (service, callback) ->
        # 1. check if package already installed, if so, we we skip download...
        @check service, (error) =>
            unless error
                service.status = { installed: true }
                @db.set service.id, service, ->
                    callback()
            else
                # 2. install service
                @install service, (error) =>
                    unless error
                        console.log 'environment variables for node'
                        console.log process.env
                        # 3. include service API module
                        filename = "#{service.description.name}/#{service.description.api}"
                        console.log 'including this file ' + filename
                        sub = require "/lib/node_modules/#{service.description.name}"
                        console.log sub
                        @include sub

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
            exec "rm -rf ./node_modules/#{desc.name}", (error, stdout, stderr) =>
                return @next new Error "Unable to remove service package '#{desc.name}': #{stderr}" if error
                @db.rm service.id, =>
                    console.log "removed service ID: #{service.id}"
                    callback()

##
# SINGLETON CLASS OBJECT
module.exports = CloudFlash

installPackages =  (desc,id, index, callback) ->
    #console.log desc
    console.log 'number of packages ' + desc.pkg.length + 'index under download is ' + index
    if index ==  desc.pkg.length
        console.log "Done installing all the packages"
        callback()
        return
    url = require 'url'
    exec = require('child_process').exec
    webreq = require 'request'
    exec = require('child_process').exec
    fs = require 'fs'
    path = require 'path'
    pkg = desc.pkg[index]
    #console.log pkg
    parsedurl = url.parse pkg, true
    console.log parsedurl
    console.log 'the protocol for the package download is ' + parsedurl.protocol
    unless parsedurl.protocol == 'npm:'
        filename = "/tmp/#{id}.#{parsedurl.protocol}"
        console.log filename
        port = 80
        port = parsedurl.port if parsedurl.port
        pkgurl = "http://" + parsedurl.hostname + ":#{port}" + "#{parsedurl.path}"
        console.log 'url to download the package:' + pkgurl
    else
        console.log 'issuing npm install'
        console.log 'parsedurl.host is '  + parsedurl.host
        console.log 'parsedurl.protocol is ' + parsedurl.protocol

    switch (parsedurl.protocol)
        when 'npm:'
            exec "npm install -g #{parsedurl.host} --prefix=/; ls -l /lib/node_modules/#{desc.name}" , (error, stdout, stderr) =>
                console.log error if error
                return callback new Error "Unable to load module using npm!" if error
                installPackages desc, id, index+1, callback
                                    
        when 'deb:'
            # 1. verify that file has been downloaded
            # 2. dpkg -i filename
            # 3. verify that package has been installed
            # 4. XXX - figure out the API endpoint dynamically
            # 5. return success message back

            webreq(pkgurl, (error, response, body) =>
                return callback new Error "Unable to download service package! #{desc.pkg[index]} Error was: #{error}" if error
                console.log "checking for service package at #{filename}"
                if path.existsSync filename
                    console.log 'found service package, issuing dpkg -i'
                    exec "dpkg -i -F depends #{filename}", (error, stdout, stderr) =>
                        return callback new Error "Unable to install service package!" if error

                        console.log "verifying that the package has been installed as #{desc.name}"
                        exec "dpkg -l #{desc.name}", (error, stdout, stderr) =>
                            return callback new Error "Unable to verify service package installation!" if error
                            installPackages desc, id, index+1, callback
                else
                    return callback new Error "Unable to download and install service debian package: #{desc.name}!"
            ).pipe(fs.createWriteStream(filename))
        when 'rpm:'
            webreq(pkgurl, (error, response, body) =>
                return callback new Error "Unable to download service package! #{desc.pkg[index]} Error was: #{error}" if error
                console.log "checking for service package at #{filename}"
                if path.existsSync filename
                    console.log 'found service package, issuing rpm -i'
                    exec "rpm -ivh #{filename}", (error, stdout, stderr) =>
                        return callback new Error "Unable to install service package!" if error

                        console.log "verifying that the package has been installed as #{desc.name}"
                        exec "rpm -q #{desc.name}", (error, stdout, stderr) =>
                            return callback new Error "Unable to verify service package installation!" if error
                            installPackages desc, id, index+1, callback
                else
                    return callback new Error "Unable to download and install service rpm package: #{desc.name}!"
            ).pipe(fs.createWriteStream(filename))
        else
            err = new Error "Unsupported protocol!#{parsedurl.protocol}"
            callback(err)
