##
# CLOUDFLASH /modules REST end-points

fileops = require 'fileops'

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
                if res.status == 304
                    @send 304
                else
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
            running: false
            result: 'unknown'

        exec "monit summary | grep #{module.description.name}", (error, stdout, stderr) =>
            console.log 'stdout : ' + stdout
            if error or stderr
               status.result =  '' + error
            else
                if stdout.match /start pending/                    
                        status.initialized = true
                else if stdout.match /Running/
                    unless stdout.match /stop pending/
                        status.initialized = true
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
                if res.status == 304
                    @send 304
                else
                    @send res
            else
                @next new Error "Invalid module posting! #{res}"

    @del '/modules/:id', loadModule, ->
        # 1. remove the module entry from DB
        cloudflash.remove @request.module, (res) =>
            unless res instanceof Error
                if res.result == 304
                    @send 304
                else
                    @send { deleted: true }                
            else
                @next res

    @post '/modules/:id/action', loadModule, ->
        return @next new Error "Invalid module posting!" unless @body.command
        module = @request.module
        desc = module.description

        console.log "looking to issue 'monit #{@body.command} #{desc.name}'"
        switch @body.command
            when "start","stop","restart"
                exec "monit #{@body.command} #{desc.name}", (error, stdout, stderr) =>                
                    return @next new Error "Unable to perform requested action!" if error
                    @send { result: true }

            else return @next new Error "Invalid action, must specify 'command' (start|stop,restart)!"

    @get '/getmodules', ->
        res = []
        nodeModules = fileops.readdirSync "/lib/node_modules"
        pattern = "^cloudflash"
        regex = new RegExp(pattern)
        for module in nodeModules
            if regex.test(module)
                console.log 'module: ' + module
                res.push module
        @send res

    
