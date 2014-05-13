EventEmitter = require('events').EventEmitter
#
# base class for all stormstack agent components
#
class StormAgent extends EventEmitter

    validate = require('json-schema').validate
    uuid = require('node-uuid')
    fs = require 'fs'
    path = require 'path'
    util = require 'util'
    extend = require('util')._extend
    async = require 'async'
    request = require 'request'

    constructor: (@config) ->
        @log 'StormAgent constructor called with:\n'+ util.inspect @config if @config?

        # need to setup some basic defaults...
        @config.port ?= 8000
        @config.repeatdelay ?= 5000
        @config.logfile ?= "/var/log/stormagent.log"

        @state ?= { }
        @state = extend @state,
            id: null
            instance: uuid.v4()
            activated: false
            running: false

        @env = require './environment'
#        @db = require('dirty') "#{@config.datadir}/stormagent.db"
        @db = require('dirty') "/tmp/stormagent.db"
        @db.on 'load', (err) =>
            @log 'loaded stormagent.db'
            @db.forEach (key,val) ->
                @log 'found ' + key if val

    # starts the agent web services API
    run: (callback) ->
        _storm = @;
        {@app} = require('zappajs') @config.port, ->
            @configure =>
              @use 'bodyParser', 'methodOverride', @app.router, 'static'
              @set 'basepath': '/v1.0'

            @configure
              development: => @use errorHandler: {dumpExceptions: on, showStack: on}
              production: => @use 'errorHandler'

            @enable 'serve jquery', 'minify'
            @storm = _storm
            @storm.include = @include

            callback() if callback?
            @storm.state.running = true
            @storm.emit 'ready'

    execute: (command, callback) ->
        unless command
            return callback new Error "no valid command for execution!"

        console.log "executing #{command}..."
        exec = require('child_process').exec
        exec command, (error, stdout, stderr) =>
            if error
                callback error
            else
                callback()

    log: util.log

    #
    # activation logic for connecting into stormstack bolt overlay network
    #
    activate: (storm, callback) ->
        count = 0
        async.until(
            () => # test condition
                @state.activated? and @state.activated

            (repeat) => # repeat function
                count++
                @log "attempting activation (try #{count})..."
                async.waterfall [
                    # 1. discover environment if no storm.tracker
                    (next) =>
                        if storm? and storm.tracker? and storm.skey?
                            return next null, storm

                        @log "discovering environment..."
                        @env.discover (storm) =>
                            if storm? and storm.tracker? and storm.skey?
                                next null, storm
                            else
                                next new Error "unable to discover environment!"

                    # 2. lookup against stormtracker and retrieve agent ID if no storm.id
                    (storm, next) =>
                        if storm.id?
                            return next null, storm

                        @log "looking up agent ID from stormtracker... #{storm.tracker}"
                        request "#{storm.tracker}/skey/#{storm.skey}", (err, res, body) =>
                            try
                                next err if err
                                switch res.statusCode
                                    when 200
                                        agent = JSON.parse body
                                        storm.id = agent.id
                                        next null, storm
                                    else next err
                            catch error
                                @log "unable to lookup: "+ error
                                next error

                    # 3. generate CSR request if no storm.cert
                    (storm, next) =>
                        if storm.cert? and storm.key?
                            return next null, storm

                        @log "generating CSR..."
                        try
                            pem = require 'pem'
                            pem.createCSR
                                country: "US"
                                state: "CA"
                                locality: "El Segundo"
                                organization: "ClearPath Networks"
                                organizationUnit: "CPN"
                                commonName: storm.id
                                emailAddress: "#{agentId}@intercloud.net"
                              , (err, res) =>
                                if res? and res.csr?
                                    @log "Activation: openssl csr generation completed , result ",res.csr
                                    storm.csr = res.csr
                                    storm.key = res.clientkey
                                    next null, storm
                                else
                                    new Error "CSR generation failure"
                        catch error
                            @log "unable to generate CSR request"
                            next error

                    # 4. get CSR signed by stormtracker if no storm.cert
                    (storm, next) =>
                        if storm.cert? and storm.key?
                            return next null,storm

                        @log "requesting CSR signing from stormtracker..."
                        r = request.post "#{storm.tracker}/#{storm.id}/csr", (err, res, body) =>
                            try
                                switch res.statusCode
                                    when 200
                                        # do something
                                        storm.cert = body
                                        next null, storm
                                    else next err
                            catch error
                                @log "unable to post CSR to get signed by stormtracker"
                                next error

                        form = r.form()
                        form.append 'file', storm.csr

                    # 5. retrieve bolt configuration if no storm.bolt
                    (storm, next) =>
                        if storm.bolt?
                            return next null,storm

                        @log "retrieving stormbolt configs from stormtracker..."
                        request "#{storm.tracker}/#{storm.id}/bolt", (err, res, body) =>
                            try
                                switch res.statusCode
                                    when 200
                                        # do something
                                        storm.bolt = JSON.parse body
                                        next null, storm
                                    else next err
                            catch error
                                @log "unable to retrieve stormbolt configs"
                                next error

                ], (err, storm) => # finally
                    if storm?
                        @log "activation completed successfully"
                        @state.activated = true
                        @emit "active", storm
                        repeat
                    else
                        @log "error during activation: #{err}"
                        setTimeout repeat, @config.repeatdelay

            (err) => # final call
                @log "final call on until..."
                callback err, @state
        )

module.exports = StormAgent

# Garbage collect every 2 sec
# Run node with --expose-gc
if gc?
    setInterval (
        () -> gc()
    ), 2000
