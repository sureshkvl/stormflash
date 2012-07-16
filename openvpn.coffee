# validation is used by other modules
validate = require('json-schema').validate

@db = db = require('dirty') '/tmp/openvpnusers.db'

db.on 'load', ->
    console.log 'loaded openvpnusers.db'
    db.forEach (key,val) ->
        console.log 'found ' + key

@lookup = lookup = (id) ->
    console.log "looking up user ID: #{id}"
    entry = db.get id
    if entry

        if schema?
            console.log 'performing schema validation on retrieved user entry'
            result = validate entry, userschema
            console.log result
            return new Error "Invalid user retrieved: #{result.errors}" unless result.valid

        return entry
    else
        return new Error "No such user ID: #{id}"

@userschema = userschema =
        name: "openvpn"
        type: "object"
        additionalProperties: false
        properties:
            id:    { type: "string", required: true }
            email: { type: "string", required: true }
            push:
                items: { type: "string" }

@include = ->

    webreq = require 'request'
    fs = require 'fs'
    path = require 'path'
    exec = require('child_process').exec

    # validation is used by other modules
    validate = require('json-schema').validate

    services = require './services'

    # testing openvpn validation with test schema
    schema =
        name: "openvpn"
        type: "object"
        additionalProperties: false
        properties:
            port:                {"type":"number", "required":true}
            dev:                 {"type":"string", "required":true}
            proto:               {"type":"string", "required":true}
            ca:                  {"type":"string", "required":true}
            dh:                  {"type":"string", "required":true}
            cert:                {"type":"string", "required":true}
            key:                 {"type":"string", "required":true}
            server:              {"type":"string", "required":true}
            'script-security':   {"type":"string", "required":false}
            multihome:           {"type":"boolean", "required":false}
            management:          {"type":"string", "required":false}
            cipher:              {"type":"string", "required":false}
            'tls-cipher':        {"type":"string", "required":false}
            auth:                {"type":"string", "required":false}
            topology:            {"type":"string", "required":false}
            'route-gateway':     {"type":"string", "required":false}
            'client-config-dir': {"type":"string", "required":false}
            'ccd-exclusive':     {"type":"boolean", "required":false}
            route:
                items: { type: "string" }
            push:
                items: { type: "string" }
            'max-clients':       {"type":"number", "required":false}
            'persist-key':       {"type":"boolean", "required":false}
            'persist-tun':       {"type":"boolean", "required":false}
            status:              {"type":"string", "required":false}
            keepalive:           {"type":"string", "required":false}
            'comp-lzo':          {"type":"string", "required":false}
            sndbuf:              {"type":"number", "required":false}
            rcvbuf:              {"type":"number", "required":false}
            txqueuelen:          {"type":"number", "required":false}
            'replay-window':     {"type":"string", "required":false}
            verb:                {"type":"number", "required":false}
            mlock:               {"type":"boolean", "required":false}

    validateOpenvpn = ->
        console.log 'performing schema validation on incoming service JSON'
        result = validate @body, schema
        console.log result
        return @next new Error "Invalid service openvpn posting!: #{result.errors}" unless result.valid
        @next()

    # helper routine for retrieving service data from dirty db
    loadService = ->
        result = services.lookup @params.id
        unless result instanceof Error
            @request.service = result
            @next()
        else
            return @next result

    @get '/services/:id/openvpn', loadService, ->
        console.log @request.service

        @render openvpn: {title: 'cloudflash opnvpnpost', layout: no}

    @post '/services/:id/openvpn', loadService, validateOpenvpn, ->
        service @request.service
        config = ''
        for key, val of @body
            switch (typeof val)
                when "object"
                    if val instanceof Array
                        for i in val
                            config += "#{key} #{i}\n" if key is "route"
                            config += "#{key} \"#{i}\"\n" if key is "push"
                when "number", "string"
                    config += key + ' ' + val + "\n"
                when "boolean"
                    config += key + "\n"

        #filename = __dirname+'/services/'+varguid+'/openvpn/server.conf'
        filename = '/config/openvpn/server.conf'
        try
            console.log "write openvpn config to #{filename}..."
            dir = path.dirname filename
            unless path.existsSync dir
                exec "mkdir -p #{dir}", (error, stdout, stderr) =>
                    unless error
                        fs.writeFileSync filename, config
            else
                fs.writeFileSync filename, config

            exec "svcs #{service.description.name} on"

            @send { result: true }
        catch err
            @next new Error "Unable to write configuration into #{filename}!"


    validateUser = ->
        console.log 'performing schema validation on incoming user validation JSON'
        result = validate @body, userschema
        console.log result
        return @next new Error "Invalid service openvpn posting!: #{result.errors}" unless result.valid
        @next()

    @post '/services/:id/openvpn/users', loadService, validateUser, ->
        service @request.service
        config = ''
        for key, val of @body
            switch (typeof val)
                when "object"
                    if val instanceof Array
                        for i in val
                            config += "#{key} #{i}\n" if key is "iroute"
                            config += "#{key} \"#{i}\"\n" if key is "push"

        #filename = "/tmp/ccd/#{@body.email}"
        filename = "/config/openvpn/ccd/#{@body.email}"
        try
            console.log "write user config to #{filename}..."
            dir = path.dirname filename
            unless path.existsSync dir
                exec "mkdir -p #{dir}", (error, stdout, stderr) =>
                    unless error
                        fs.writeFileSync filename, config
            else
                fs.writeFileSync filename, config

            exec "svcs #{service.description.name} sync"

            db.set @params.id, @body, =>
                console.log "#{@body.email} added to OpenVPN service configuration"
                console.log @body

                @send { result: true }
        catch err
            @next new Error "Unable to write configuration into #{filename}!"

