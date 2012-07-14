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

    schema =
        name: "service"
        type: "object"
        additionalProperties: false
        properties:
            id:     {"type": "string"}
            name:   {"type": "string", "required": true}
            family: {"type": "string", "required": true}
            version:{"type": "string", "required": true}
            pkgurl: {"type": "string", "required": true}
            api:    {"type": "string", "required": true}
            status: {"type": "string"}

    @get '/services': ->
        res = { 'services': [] }
        db.forEach (key,val) ->
            console.log 'found ' + key
            res.services.push val
        @send res

    validateService = ->
        console.log 'performing schema validation on incoming service JSON'
        result = validate @body.service, schema
        return @next new Error "Invalid service posting!: #{result.errors}" unless result.valid
        @next()

    # helper routine for retrieving service data from dirty db
    loadService = ->
        console.log "loading service ID: #{@params.id}"
        entry = db.get @params.id
        if entry
            @body.service ?= entry.service
            console.log 'performing schema validation on incoming/retrieved JSON'
            
            result = validate @body.service, schema
            return @next new Error "Invalid service posting!: #{result.errors}" unless result.valid
            @next()
        else
            @next new Error "No such service ID: #{@params.id}"

    loadServiceaction = ->
        console.log "loading service ID: #{@params.id} for action"
        entry = db.get @params.id
        if !entry
            @next new Error "No such service ID: #{@params.id}"
        @next()
        

    @post '/services', validateService, ->
        # POST VALIDATION
        # 1. need to make sure the incoming JSON is well formed
        # 2. destructure the inbound object with proper schema
        service = @body.service
        service.id = uuid.v4()

        # let's download this file from the web
        filename = "/tmp/#{service.id}.pkg"
        webreq(service.pkgurl, (error, response, body) =>
            # 1. verify that file has been downloaded
            # 2. dpkg -i filename
            # 3. verify that package has been installed
            # 4. return success message back
            return @next new Error "Unable to download service package!" if error

            console.log "checking for service package at #{filename}"
            if path.existsSync filename
                console.log 'found service package, issuing dpkg -i'
                exec "dpkg -i -F depends #{filename}", (error, stdout, stderr) =>
                    return @next new Error "Unable to install service package!" if error

                    console.log "verifying that the package has been installed as #{service.name}"
                    exec "dpkg -l #{service.name}", (error, stdout, stderr) =>
                        return @next new Error "Unable to verify service package installation!" if error
                        service.status = "installed"
                        @body.service = service
                        db.set service.id, @body, =>
                        console.log "#{service.pkgurl} downloaded and installed successfully as service ID: #{service.id}"
                        @send @body
            else
                return @next new Error "Unable to download and install service package!"
            ).pipe(fs.createWriteStream(filename))

    @get '/services/:id', loadService, ->
        @send @body

    @put '/services/:id', validateService, loadService, ->
        @body.service.id = @params.id
        # XXX - can have intelligent merge here

        # PUT VALIDATION
        # 1. need to make sure the incoming JSON is well formed
        # 2. destructure the inbound object with proper schema
        # 3. perform 'extend' merge of inbound service data with existing data

        db.set @params.id, @body, ->
            console.log "updated service ID: #{@params.id}"
            @send @body
            # do some work

    @del '/services/:id', loadService, ->
        # 1. verify that the package is actually installed
        # 2. perform dpkg -r PACKAGENAME
        # 3. remove the service entry from DB
        service = @body.service
        console.log "verifying that the package has been installed as #{service.name}"
        delFilePath = __dirname+'/services/'+service.id
        exec "dpkg -l #{service.name}", (error, stdout, stderr) =>
            return @next new Error "Unable to verify service package installation!" if error

            console.log "removing the service package: dpkg -r #{service.name}"
            exec "dpkg -r #{service.name}", (error, stdout, stderr) =>
                return @next new Error "Unable to remove service package: #{service.name}!" if error
                db.rm service.id, =>
                    console.log "removed service ID: #{service.id}"
                    exec "rm -rf #{delFilePath}", (error, stdout, stderr) =>
                         return @next new Error "Unable to remove services directory : #{service.name}!" if error
                    @send '{ deleted: ok }'

    @post '/services/:id/action', loadServiceaction, ->
        return @next new Error "Invalid service posting!" unless @body.command
        service = db.get @params.id
        message = {'services':{}}
        message.services.id   = @params.id
        message.services.name = service.service.name               
        #message.services.type = service.service.type
                    
        console.log service.service
        console.log "looking to issue 'svcs #{service.service.name} #{@body.command}'"
        switch @body.command
            when "start","stop","restart"
                #exec "svcs #{service.service.name} #{@body.command}", (error, stdout, stderr) =>
                exec "pwd", (error, stdout, stderr) => 
                    return @next new Error "Unable to perform requested action!" if error                              
                    message.services.action = "success"                                    
                    @send message

            when "status"
                # for debugging the below command is uncommented. Kindly enable this
                exec "svcs #{service.service.name} #{@body.command}", (error, stdout, stderr) =>
                 #exec "pwd", (error, stdout, stderr) =>
                    return @next new Error "Unable to perform requested action!" if error

                    # the strObj we capture the stdout and process the return values to foramt a gud JSON string
                    strObj = stdout
                    
                    #strObj = "#{service.service.name} is enabled and running pid as 847"
                    console.log strObj
                    if strObj
                      if strObj.indexOf("disabled") > 0                      
                        message.services.enabled = 'false'
                        message.services.status ='Not Running'
                        message.services.action = "failed"
                      else
                        message.services.enabled = 'true'
                        if strObj.indexOf("not") > 0                        
                          message.services.status ='Not Running'
                          message.services.action = "failed"
                        else
                          IndexLen = parseInt(strObj.indexOf("as"))
                          unless IndexLen is -1
                            indexArr = strObj.split(" ")
                            message.services.pid =parseInt(indexArr[indexArr.length - 1]) if indexArr.length > 0

                        message.services.status = 'running'
                        message.services.action = "success"
                        result: "#{stdout}"
                    console.log message
                    @send message

            else return @next new Error "Invalid action, must define 'command'!"

