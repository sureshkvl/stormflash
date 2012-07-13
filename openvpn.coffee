@include = ->
    uuid = require('node-uuid')
    db   = require('dirty') '/tmp/cloudflash.db'

    webreq = require 'request'
    fs = require 'fs'
    path = require 'path'
    exec = require('child_process').exec

    # validation is used by other modules
    validate = require('json-schema').validate

    #db.on 'load', ->
    #    console.log 'loaded cloudflash.db'
    #   db.forEach (key,val) ->
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
	    	        
    validateOpenvpn = ->
        console.log 'performing schema validation on incoming service JSON'
        result = validate @body.services.openvpn, schema
        return @next new Error "Invalid service openvpn posting!: #{result.errors}" unless result.valid
        @next() 

    loadOpenvpn = ->
        console.log "loading service ID: #{@params.id}"
        service = db.get @params.id
        if service
            #@body.service ?= service
            @next()
        else
            @next new Error "No such service ID: #{@params.id}"

    @get '/services/:id/openvpn', loadOpenvpn, ->
        var1 = @params.id
        console.log 'guid:'+var1
        #@body.service.id = var1
        @render openvpn: {title: 'cloudflash opnvpnpost', layout: no}

    @post '/services/:id/openvpn', loadOpenvpn, validateOpenvpn, ->
        return @next new Error "Invalid service openvpn posting!" unless @body.services and @body.services.openvpn
        varguid = @params.id
        console.log "here in openvpn post" + varguid
        console.log @body.services.openvpn
	
	# if the data arrrives as encoded base64 utf8 then we need 
	# to decode it. just uncomment the following lines and 
	# pass decode data to obj instead of @body.services.openvpn
	
        #encodeData = @body.services.openvpn
        #dcodData = new Buffer(encodeData,"base64").toString("utf8")
        #console.log 'result:' + dcodData
        
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


