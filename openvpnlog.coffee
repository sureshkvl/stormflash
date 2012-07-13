@include = ->
    uuid = require('node-uuid')
    db   = require('dirty') '/tmp/cloudflash.db'

    webreq = require 'request'
    fs = require 'fs'
    path = require 'path'
    exec = require('child_process').exec

    # validation is used by other modules
    # validate = require('json-schema').validate

    #db.on 'load', ->
    #    console.log 'loaded cloudflash.db'
    #    db.forEach (key,val) ->
    #        console.log 'found ' + key

    # testing openvpn validation with test schema
    schema =
        name: "openvpn"
        type: "object"
        additionalProperties: false
        properties:
            port:  {"type": "number", "required": true}
            dev:   {"type": "string", "required": true}
            proto: {"type": "string", "required": true}
            ca: {"type":"string", "required":true}
            dh: {"type":"string", "required":true}
            cert: {"type":"string", "required":true}
            key: {"type":"string", "required":true}
            server: {"type":"string", "required":true}
            'script-security': {"type":"string", "required":false}
            multihome: {"type":"string", "required":false}
            management: {"type":"string", "required":false}
            cipher: {"type":"string", "required":false}    
            'tls-cipher': {"type":"string", "required":false}
            auth: {"type":"string", "required":false}
            topology: {"type":"string", "required":false}
            'route-gateway': {"type":"string", "required":false}   
            'client-config-dir': {"type":"string", "required":false}
            'ccd-exclusive': {"type":"string", "required":false}
            route: {"type":"string", "required":false}
            push: {"type":"string", "required":false}
            'max-clients': {"type":"number", "required":false}
            'persist-key': {"type":"string", "required":false}
            'persist-tun': {"type":"string", "required":false}
            status: {"type":"string", "required":false}
            keepalive: {"type":"string", "required":false}
            'comp-lzo': {"type":"string", "required":false}
            sndbuf: {"type":"number", "required":false}
            rcvbuf: {"type":"number", "required":false}
            txqueuelen: {"type":"string", "required":false}
            'replay-window': {"type":"string", "required":false}
            verb: {"type":"number", "required":false}
            mock: {"type":"string", "required":false}
	    
    loadgetlogStatus = ->
        console.log "loading service ID: #{@params.id}"
        service = db.get @params.id
        if service
            #@body.service ?= service
            @next()
        else
            @next new Error "No such service ID: #{@params.id}"


    @get '/services/:id/openvpn/server', loadgetlogStatus, ->
                key = []
                val = []
                openvpn = '{ "openvpn" : {'
                connected = ' "connected" : [ '
                i = 1
                for line in fs.readFileSync("openvpn-status.log").toString().split '\n'
                        if line=='ROUTING TABLE'
                                break
                        if i<=2
                                i++
                                continue
                        if 3==i
                                for word in line.split ','
                                        key.push word
                        else if i>=4
                                val = []
                                for word in line.split ','
                                        val.push word
                        i++
                        j = 0
                        keyval ='{'
                        while j < 5
                                if val[j]
                                        pair = '"' + key[j] + '"' + " : " + '"' + val[j] + '"'
                                        keyval = keyval + pair 
                                        if j < 4
                                                keyval = keyval + ','
                                j++
                        keyval = keyval + ' }'
                        if val[0]
                                connected = connected + keyval
                connected = connected + ']'
                openvpn = openvpn + connected + '} }'
                @send openvpn
