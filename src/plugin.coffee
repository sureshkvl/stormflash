# stormflash agent API endpoints
# when 'imported' from another stormflash agent,

StormPackage = require('./stormflash').StormPackage

@include = ->

    agent = @settings.agent

    @post '/packages': ->
        console.log agent
        agent.install @body, (result) =>
            if result instanceof Error
                @send 500
            else
                @send 200

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
            result = agent.remove match
            @send 204 if result is undefined
            @send 500
        else
            @send 404
