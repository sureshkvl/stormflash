##
# CLOUDFLASH /services REST end-points

@include = ->
    cloud = require('./cloudflash')
    cloudflash = new cloud(@include)

    @get '/services': ->
        res = cloudflash.list()
        console.log res
        @send res

    # POST/PUT VALIDATION
    # 1. need to make sure the incoming JSON is well formed
    # 2. destructure the inbound object with proper schema
    validateServiceDesc = ->
        console.log @body
        result = cloudflash.validate @body
        console.log result
        return @next new Error "Invalid service posting!: #{result.errors}" unless result.valid
        @next()

    # helper routine for retrieving service data from dirty db
    loadService = ->
        result = cloudflash.lookup @params.id
        unless result instanceof Error
            @request.service = result
            @next()
        else
            return @next result

    @post '/services', validateServiceDesc, ->
        service = cloudflash.new @body
        cloudflash.add service, (error) =>
            unless error
                console.log service
                @send service
            else
                @next error

    @get '/services/:id', loadService, ->
        service = @request.service

        # for debugging the below command is uncommented. Kindly enable this
        #exec "pwd", (error, stdout, stderr) =>
        exec "svcs #{service.description.name} status", (error, stdout, stderr) =>
            if error or not stdout?
                service.status = null
            else
                status =
                    installed: service.status?.installed?
                    initialized: false
                    enabled: false
                    running: false
                    result: stdout

                console.log stdout

                if stdout.match /disabled/
                    status.initialized = true
                else if stdout.match /enabled/
                    status.enabled = true
                    unless stdout.match /not running/
                        status.running = true

                service.status = status

            console.log service
            @send service


    @put '/services/:id', validateServiceDesc, loadService, ->
        # XXX - can have intelligent merge here

        # PUT VALIDATION
        # 1. need to make sure the incoming JSON is well formed
        # 2. destructure the inbound object with proper schema
        # 3. perform 'extend' merge of inbound service data with existing data
        service = @request.service

        # desc = @body
        # @body = entry
        # @body.description ?= desc if desc?

        db.set service.id, service, ->
            console.log "updated service ID: #{service.id}"
            console.log service
            @send service
            # do some work

    @del '/services/:id', loadService, ->
        # 1. verify that the package is actually installed
        # 2. perform dpkg -r PACKAGENAME
        # 3. remove the service entry from DB
        cloudflash.remove @request.service, =>
            unless error
                @send { deleted: true }
            else
                @next error

    @post '/services/:id/action', loadService, ->
        return @next new Error "Invalid service posting!" unless @body.command
        service = @request.service
        desc = service.description

        console.log "looking to issue 'svcs #{desc.name} #{@body.command}'"
        switch @body.command
            when "on", "start", "off", "stop","restart", "sync"
                exec "svcs #{desc.name} #{@body.command}", (error, stdout, stderr) =>
                #exec "pwd", (error, stdout, stderr) =>
                    return @next new Error "Unable to perform requested action!" if error
                    @send { result: true }

            else return @next new Error "Invalid action, must specify 'command' (on|off,start|stop,restart,sync)!"

    ##
    # TEST ENDPOINTS

    @get '/test/services': ->
        cloudflash.list()

        service = cloudflash.lookup 'helloworld'
        console.log service

        service = cloudflash.new {
            version: '1.0'
            name: 'at'
            family: 'remote-access'
            pkgurl: 'http://10.1.10.145/vpnrac-0.0.1.deb'
        }

        cloudflash.add service, (error) =>
            unless error
                console.log 'added successfully'
                @send service
            else
                console.log 'adding failed'
                @next error

