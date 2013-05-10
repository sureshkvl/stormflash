##
# CLOUDFLASH /modules REST end-points

@include = ->
    cloud = require('./cloudflash')
    cloudflash = new cloud(@include)
    exec = require('child_process').exec

    @get '/modules': ->
        res = cloudflash.list()
        console.log res
        @send res

    # POST/PUT VALIDATION
    # 1. need to make sure the incoming JSON is well formed
    # 2. destructure the inbound object with proper schema
    validateModuleDesc = ->
        console.log @body
        result = cloudflash.validate @body
        console.log result
        return @next new Error "Invalid module posting!: #{result.errors}" unless result.valid
        @next()

    # helper routine for retrieving module data from dirty db
    loadModule = ->
        result = cloudflash.lookup @params.id
        unless result instanceof Error
            @request.module = result
            @next()
        else
            return @next result

    @post '/modules', validateModuleDesc, ->
        module = cloudflash.new @body
        cloudflash.add module,'', true, (res) =>
            unless res instanceof Error
                @send res
            else
                @next new Error "Invalid module posting! #{res}"
            

    @get '/modules/:id', loadModule, ->
        module = @request.module

        installed = null
        if module.status
            installed = true
        status =
            installed: installed ? false
            initialized: false
            enabled: false
            running: false
            result: 'unknown'

        exec "svcs #{module.description.name} status", (error, stdout, stderr) =>
            if error or stderr
               status.result =  '' + error
            else
                if stdout.match /disabled/
                    status.initialized = true
                else if stdout.match /enabled/
                    status.enabled = true
                    unless stdout.match /not running/
                        status.running = true

                status.result = stdout

            module.status = status

            console.log module
            @send module


    @put '/modules/:id', validateModuleDesc, loadModule, ->
        # XXX - can have intelligent merge here

        # PUT VALIDATION
        # 1. need to make sure the incoming JSON is well formed
        # 2. destructure the inbound object with proper schema
        # 3. perform 'extend' merge of inbound module data with existing data
        module = cloudflash.new @body, @params.id       

        # desc = @body
        # @body = entry
        # @body.description ?= desc if desc?

        cloudflash.update module, @request.module, (res) =>
            unless res instanceof Error
                @send res
            else
                @next new Error "Invalid module posting! #{res}"

    @del '/modules/:id', loadModule, ->
        # 1. verify that the package is actually installed
        # 2. perform dpkg -r PACKAGENAME
        # 3. remove the module entry from DB
        cloudflash.remove @request.module, (error) =>
            unless error
                @send { deleted: true }
            else
                @next error

    @post '/modules/:id/action', loadModule, ->
        return @next new Error "Invalid module posting!" unless @body.command
        module = @request.module
        desc = module.description

        console.log "looking to issue 'svcs #{desc.name} #{@body.command}'"
        switch @body.command
            when "on", "start", "off", "stop","restart", "sync"
                exec "svcs #{desc.name} #{@body.command}", (error, stdout, stderr) =>
                #exec "pwd", (error, stdout, stderr) =>
                    return @next new Error "Unable to perform requested action!" if error
                    @send { result: true }

            else return @next new Error "Invalid action, must specify 'command' (on|off,start|stop,restart,sync)!"

    
