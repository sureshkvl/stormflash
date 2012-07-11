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

    webreq = require 'request'
    fs = require 'fs'

    db.on 'load', ->
        console.log 'loaded cloudflash.db'

    @get '/services': ->
        res = { 'services': [] }
        db.forEach (key,val) ->
            console.log 'found ' + key
            res.services.push val
        @send res

    @post '/services': ->
        return @next new Error "Invalid service posting!" unless @body.service?

        @body.pkgurl ?= 'http://www.google.com/images/srpr/logo3w.png'

        # let's download this file from the web
        id = uuid.v4()
        filename = "/tmp/#{id}.pkg"
        webreq(@body.pkgurl).pipe(fs.createWriteStream(filename)) if @body.pkgurl?

        # invoke dpkg -i on filename, get the response code and if we downloaded ok, then...
        # 1. verify that file has been downloaded
        # 2. dpkg -i filename
        # 3. verify that package has been installed

        @body.service.id = id
        db.set id, @body, =>
            console.log "#{@body.pkgurl} downloaded and installed successfully as service ID: #{id}"
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
        # can have intelligent merge here

        db.set @params.id, @body, ->
            console.log "updated service ID: #{@params.id}"
            @send @body
            # do some work

    @del '/services/:id', loadService, ->
        db.rm @params.id, ->
            console.log "removed service ID: #{@params.id}"
            @send ''
            # do some work

    # @include 'firewall'

    # @include 'openvpn'


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
#          @emit 'set nickname': {nickname: prompt 'Pick a nickname!'}

          $('#box').focus()

          $('button').click (e) =>
            data = { 'service': $('#services').serializeFormJSON() }
            json = JSON.stringify(data)
            $.ajax
                type: "POST"
                url: '/services'
                data: json
                contentType: "application/json; charset=utf-8"
                success: ->
                    console.log 'yay'
            e.preventDefault()

    @view index: ->
        doctype 5
        html ->
          head ->
            title 'CloudFlash Test Application!'
            script src: '/socket.io/socket.io.js'
            script src: '/zappa/jquery.js'
            script src: '/zappa/zappa.js'
            script src: '/jquery-json.js'
            script src: '/index.js'
          body ->
            div id: 'panel'
            form '#services', ->
                p ->
                    span 'Service Name: '
                    input '#name'
                        type: 'text'
                        name: 'name'
                        placeholder: 'iptables'
                p ->
                    span 'Service Type: '
                    input '#type',
                        type: 'text'
                        name: 'type'
                        placeholder: 'firewall'
                p ->
                    span 'Package URL: '
                    input '#pkgurl',
                        type: 'text'
                        name: 'pkgurl'
                        placeholder: 'http://www.getmyfireall.here.com'
                button 'Send'
