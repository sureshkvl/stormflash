# stormflash agent API endpoints
# when 'imported' from another stormflash agent,

StormPackage = require('./stormflash').StormPackage

@include = ->

    agent = @settings.agent

    @post '/packages': ->
        agent.install @body, (result) =>
            unless result instanceof Error
                @send result
            else
                @next new Error result

    @get '/packages': ->
        @send agent.packages.list()

    @get '/packages/:id': ->
        match = agent.packages.get @params.id
        unless match is undefined
            @send match
        else
            @send 404

    @put '/packages/:id': ->
        @send new Error "updating package currently not supported!"
        ###
        match = agent.packages.get @params.id
        if match?
            @send agent.upgrade match, @body
        else
            @send 404
        ###

    @del '/packages/:id': ->
        match = agent.packages.get @params.id
        if match?
            result = agent.uninstall match
            if result is undefined
                @send 204
            else
                @next 500
        else
            @send 404
