{@app} = require('zappajs') ->
    @configure =>
      @use 'bodyParser', 'methodOverride', @app.router, 'static'
      @set 'basepath': '/v1.0'

    @configure
      development: => @use errorHandler: {dumpExceptions: on, showStack: on}
      production: => @use 'errorHandler'

    @enable 'serve jquery', 'minify'

    uuid = require('node-uuid')
    db   = require('dirty') '/tmp/cloudflash.db'

    db.on 'load', ->
        console.log 'loaded cloudflash.db'
        ## below for debugging only
        console.log 'debug: add a service entry every time'
        id = uuid.v4()
        db.set id,
            service:
                id: id
                name: 'iptables'
                type: 'firewall'
            ->
                console.log 'saved a dummy entry for testing'

    @get '/services': ->
        res = { 'services': [] }
        db.forEach (key,val) ->
            console.log 'found ' + key
            res.services.push val
        @send res

    @post '/services': ->
        return @next new Error "Invalid service posting!" unless @body.service?

        id = uuid.v4()
        @body.service.id = id
        db.set id, @body, ->
            console.log 'test saved'
            @send @body

    # helper routine for retrieving service data from dirty db
    loadService = ->
        console.log "loading service ID: #{@params.id}"
        service = db.get @params.id
        if service
            @body.service ?= service
            @next()
        else
            @next new Error "No such service ID: #{@params.id}"

    @get '/services/:id', loadService, ->
        @send @body

    @put '/services/:id', loadService, ->
        @body.service.id = @params.id
        db.set @params.id, @body, ->
            console.log "updated service ID: #{@params.id}"
            @send @body
            # do some work

    @del '/services/:id', loadService, ->
        db.rm @params.id, ->
            console.log "removed service ID: #{@params.id}"
            @send ''
            # do some work

#
#sample program
#

    @get '/': ->
        @render index: {title: 'cloudflash', layout: no}

    @on 'set nickname': ->
        @client.nickname = @data.nickname

    @on said: ->
        @broadcast said: {nickname: @client.nickname, text: @data.text}
        @emit said: {nickname: @client.nickname, text: @data.text}

    @client '/index.js': ->
        @connect()

        @on said: ->
          $('#panel').append "<p>#{@data.nickname} said: #{@data.text}</p>"

        $ =>
          @emit 'set nickname': {nickname: prompt 'Pick a nickname!'}

          $('#box').focus()

          $('button').click (e) =>
            @emit said: {text: $('#box').val()}
            $('#box').val('').focus()
            e.preventDefault()

    @view index: ->
        doctype 5
        html ->
          head ->
            title 'PicoChat!'
            script src: '/socket.io/socket.io.js'
            script src: '/zappa/jquery.js'
            script src: '/zappa/zappa.js'
            script src: '/index.js'
          body ->
            div id: 'panel'
            form ->
              input id: 'box'
              button 'Send'
