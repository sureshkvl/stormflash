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
            'comp-lzo':          {"type":"boolean", "required":false}
            sndbuf:              {"type":"number", "required":false}
            rcvbuf:              {"type":"number", "required":false}
            txqueuelen:          {"type":"number", "required":false}
            'replay-window':     {"type":"string", "required":false}
            verb:                {"type":"number", "required":false}
            mock:                {"type":"boolean", "required":false}

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
        resp = {'services':{}}
        varguid = @params.id
        resp.services.id = varguid
        resp.services.name = "openvpn"
        obj = @body.services.openvpn
        filename = __dirname+'/services/'+varguid+'/openvpn/server.conf'
        if path.existsSync filename
           resData = ''
           for i of obj
             resData = resData + i + ' ' + obj[i] + "\n"  unless typeof (obj[i]) is "object"
           resData

           if resData
             try
               fs.writeFileSync filename, resData
               resp.services.config = "success"
             catch err
               resp.services.config = "failed"
           else
             resp.services.config = "failed"

           @send resp
        else
           return @next new Error "Unable to find file #{filename}!"

    @post '/services/:id/openvpn/users', loadService, ->

