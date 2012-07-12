@include = ->
    uuid = require('node-uuid')
    db   = require('dirty') '/tmp/cloudflash.db'

    webreq = require 'request'
    fs = require 'fs'
    path = require 'path'
    exec = require('child_process').exec

    # validation is used by other modules
    validate = require('json-schema').validate

    db.on 'load', ->
        console.log 'loaded cloudflash.db'
        db.forEach (key,val) ->
            console.log 'found ' + key

    # testing openvpn validation with test schema
    schema =
        name: "openvpn"
        type: "object"
        additionalProperties: false
        properties:
            port:  {"type": "string"}
            dev:   {"type": "string", "required": true}
            proto: {"type": "string", "required": true}       

    
    validateOpenvpn = ->
        console.log 'performing schema validation on incoming service JSON'
        result = validate @body.services.openvpn, schema
        return @next new Error "Invalid service openvpn posting!: #{result.errors}" unless result.valid
        @next() 

    @get '/services/:id/openvpn': ->
        var1 = @params.id
        console.log 'guid:'+var1
        #@body.service.id = var1
        @render openvpn: {title: 'cloudflash opnvpnpost', layout: no}

    @post '/services/:id/openvpn', validateOpenvpn, ->
        return @next new Error "Invalid service openvpn posting!" unless @body.services and @body.services.openvpn
        varguid = @params.id
        console.log "here in openvpnpost" + varguid
        console.log @body.services.openvpn
        id = uuid.v4()
        obj = @body.services.openvpn	 
        filename = __dirname+'/services/'+varguid+'/openvpn/server.conf'
        console.log 'filename:'+filename
        if path.existsSync filename           
           resData = ''
           for i of obj
    	      #console.log 'here i:' + i
             resData = resData + i + ' ' + obj[i] + "\n"  unless typeof (obj[i]) is "object"
           resData

           console.log 'found file' + resData
           fs.writeFileSync filename, resData
           @send @body
        else
           return @next new Error "Unable to find file!"


