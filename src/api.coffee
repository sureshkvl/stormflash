# stormflash agent API endpoints
# when 'imported' from another stormflash agent,

#require './spm'

@include = ->

    validate = require('json-schema').validate
    schema = {}

    @get '/': ->
        util = require('util')
        util.log "get / with agent: "+util.inspect @agent
        res = @agent.env.os()
        console.log res
        @send res

# /environment

    @get '/environment': ->
        res = @agent.env.os()
        console.log res
        @send res

    @get '/bolt': ->
       x= require('./activation').getBoltData()
       console.log x
       @send x

# /packages
    schema.packages =
        name: "packages"
        type: "object"
        required: true
        properties:
            name : { type: "string", "required": true }
            version : { type: "string", "required": true }
            source : { type: "string", "required": true }

    @post '/packages': ->
        console.log JSON.stringify @body
        result = validate @body, schema.packages
        @agent.log result
        pkg = new StormPackage @body
        @agent.install pkg, (res) =>
            @agent.log res
            @send res

    @get '/packages': ->
        @agent.list (res) =>
            console.log res
            @send res

# /personality
    schema.personality =
        name: "personality"
        type: "object"
        items:
            type: "object"
            additionalProperties: false
            properties:
                path:     { type: "string", required: true }
                contents: { type: "string", required: true }
                postxfer: { type: "string" }

    @post '/personality': ->
        console.log 'performing schema validation on incoming service JSON'

        #console.log @body

        result = validate @body, schema.personality
        console.log result
        return @next new Error "Invalid personality posting!: #{result.errors}" unless result.valid

        fs = require 'fs'
        exec = require('child_process').exec
        path = require 'path'

        for p in @body.personality
            #console.log p
            do (p) ->
                console.log "writing personality to #{p.path}..."
                # debug /tmp
                # p.path = '/tmp'+p.path
                dir = path.dirname p.path
                unless path.existsSync dir
                    exec "mkdir -p #{dir}", (error, stdout, stderr) =>
                        unless error
                            fs.writeFile p.path, new Buffer(p.contents || '',"base64"), ->
                                # this feature currently disabled DO NOT re-enable!
                                if p.postxfer?
                                    exec "#{p.postxfer}", (error, stdout, stderr) ->
                                        console.log "issuing '#{p.postxfer}'... stderr: #{stderr}" if error
                                        console.log "issuing '#{p.postxfer}'... stdout: #{stdout}" unless error
                else
                    fs.writeFile p.path, new Buffer(p.contents || '',"base64"), ->
                        # this feature currently disabled DO NOT re-enable!
                        if p.postxfer?
                            exec "#{p.postxfer}", (error, stdout, stderr) ->
                                console.log "issuing '#{p.postxfer}'... stderr: #{stderr}" if error
                                console.log "issuing '#{p.postxfer}'... stdout: #{stdout}" unless error

        @send { result: 'success' }

# /plugins

    fs = require 'fs'
    exec = require('child_process').exec

    @get '/plugins': ->
        res = @agent.list()
        console.log res
        @send res

    # POST/PUT VALIDATION
    # 1. need to make sure the incoming JSON is well formed
    # 2. destructure the inbound object with proper schema
    validateModuleDesc = ->
        console.log @body
        result = @agent.validate @body
        console.log result
        return @next new Error "Invalid module posting!: #{result.errors}" unless result.valid
        @next()

    # helper routine for retrieving module data from dirty db
    loadModule = ->
        result = @agent.lookup @params.id
        unless result instanceof Error
            @request.module = result
            @next()
        else
            return @next result

    @post '/plugins', validateModuleDesc, ->
        module = @agent.new @body
        @agent.add module,'', true, (res) =>
            unless res instanceof Error
                if res.status == 304
                    @send 304
                else
                    @send res
            else
                @next new Error "Invalid module posting! #{res}"


    @get '/plugins/:id', loadModule, ->
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


    @put '/plugins/:id', validateModuleDesc, loadModule, ->
        # XXX - can have intelligent merge here

        # PUT VALIDATION
        # 1. need to make sure the incoming JSON is well formed
        # 2. destructure the inbound object with proper schema
        # 3. perform 'extend' merge of inbound module data with existing data
        module = @agent.new @body, @params.id

        # desc = @body
        # @body = entry
        # @body.description ?= desc if desc?

        @agent.update module, @request.module, (res) =>
            unless res instanceof Error
                if res.status == 304
                    @send 304
                else
                    @send res
            else
                @next new Error "Invalid module posting! #{res}"

    @del '/plugins/:id', loadModule, ->
        # 1. remove the module entry from DB
        @agent.remove @request.module, (res) =>
            unless res instanceof Error
                if res.result == 304
                    @send 304
                else
                    @send { deleted: true }
            else
                @next res

    @post '/plugins/:id/action', loadModule, ->
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
        nodeModules = fs.readdirSync "/lib/node_modules"
        pattern = "^stormflash"
        regex = new RegExp(pattern)
        for module in nodeModules
            if regex.test(module)
                console.log 'module: ' + module
                res.push module
        @send res


