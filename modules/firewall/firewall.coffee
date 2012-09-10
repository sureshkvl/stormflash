@include = ->
    uuid = require('node-uuid')
    db   = require('dirty') '/tmp/cloudflash.db'

    webreq = require 'request'
    fs = require 'fs'
    path = require 'path'
    exec = require('child_process').exec

    # validation is used by other modules
    validate = require('json-schema').validate

    loadFirewall = ->
        console.log "loading service ID: #{@params.id}"
        service = db.get @params.id
        if service
            #@body.service ?= service
            @next()
        else
            @next error = new Error "No such service ID: #{@params.id}"        

    @get '/services/:id/firewall', loadFirewall, ->     
        @render firewall: {title: 'cloudflash firewall post', layout: no}

    @post '/services/:id/firewall', loadFirewall, ->
        return @next error = new Error "Invalid service firewall posting!" unless @body.services and @body.services.firewall and @body.services.firewall.command
        resp = {'services':{}}
        varguid = @params.id
        resp.services.id = varguid
        resp.services.name = "iptable"                
        obj = @body.services.firewall	 
        filename = __dirname+'/services/'+varguid+'/firewall/firewall.sh'                
        if path.existsSync filename
           encodeData = obj.command
           dcodData = new Buffer(encodeData,"base64").toString("utf8")
           #console.log 'result:' + dcodData
           try                    
             fs.writeFileSync filename, dcodData
             resp.services.command = "success"
           catch err
             resp.services.command = "failed"
           @send resp
        else
           return @next error = new Error "Unable to find file #{filename}!"


