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
    #    db.forEach (key,val) ->
    #        console.log 'found ' + key

    # testing firewall validation with test schema
    #final validations to be and full schema to be added
    schemafirewall =
        name: "firewall"
        type: "object"
        additionalProperties: false
        properties:
            LOGFILE:  {"type": "string"}
            LOGFORMAT:   {"type": "string", "required": true}
            LOGTAGONLY: {"type": "string", "required": true}       

    
    validateFirewall = ->
        console.log 'performing schema validation on incoming service JSON'
        result = validate @body.services.firewall, schemafirewall 
        return @next new Error "Invalid service firewall posting!: #{result.errors}" unless result.valid
        @next() 

    loadFirewall = ->
        console.log "loading service ID: #{@params.id}"
        service = db.get @params.id
        if service
            #@body.service ?= service
            @next()
        else
            @next new Error "No such service ID: #{@params.id}"

    @get '/services/:id/firewall', loadFirewall, ->
        var1 = @params.id
        console.log 'guid:'+var1
        #@body.service.id = var1
        @render firewall: {title: 'cloudflash firewall post', layout: no}

    @post '/services/:id/firewall', loadFirewall, validateFirewall, ->
        return @next new Error "Invalid service firewall posting!" unless @body.services and @body.services.firewall
        varguid = @params.id
        console.log "here in firewall post" + varguid
        console.log @body.services.firewall
        #encodeData = @body.services.firewall
        #dcodData = new Buffer(encodeData,"base64").toString("utf8")
        #console.log 'result:' + dcodData
        id = uuid.v4()
        obj = @body.services.firewall	 
        filename = __dirname+'/services/'+varguid+'/firewall/shorewall.conf'
        console.log 'filename:'+filename
        if path.existsSync filename           
           resData = ''
           for i of obj    	      
             resData = resData + i + '=' + obj[i] + "\n"  unless typeof (obj[i]) is "object"
           resData
           console.log 'found file' + resData
           fs.writeFileSync filename, resData
           @send @body
        else
           return @next new Error "Unable to find file!"


