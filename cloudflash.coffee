str = ' '
obj = ''
traverseConfigObj = (obj, str) ->
  resData = ""
  for i of obj
    #console.log 'here i:' + i
    if typeof (obj[i]) is "object"
      resData = resData + traverseConfigObj(obj[i], str)
    else
      resData = resData + i + str + obj[i] + "\n"
  resData

{@app} = require('zappajs') ->
    @configure =>
      @use 'bodyParser', 'methodOverride', @app.router, 'static'
      @set 'basepath': '/v1.0'

    @configure
      development: => @use errorHandler: {dumpExceptions: on, showStack: on}
      production: => @use 'errorHandler'

    @enable 'serve jquery', 'minify'

    @include 'services'

    # @include 'firewall'

    # @include 'openvpn'
    @post '/services/:id/openvpn': ->
        return @next new Error "Invalid service openvpn posting!" unless @body.services and @body.services.openvpnpostdata
        varguid = @params.id
        console.log "here in openvpnpost" + varguid
        console.log @body.services.openvpnpostdata
        id = uuid.v4()
        obj = @body.services.openvpnpostdata

	 #filename = __dirname + '/services/'+ varguid +'openvpn/server.conf'
        filename = __dirname+'/services/'+varguid+'/openvpn/server.conf'
        console.log 'filename:'+filename
        if path.existsSync filename
           retObj = traverseConfigObj(obj,str)
           console.log 'found file' + retObj
           fs.writeFileSync filename, retObj
           @send @body
        else
           return @next new Error "Unable to find file!"

        #console.log 'redobj:'+retObj
	 #console.log 'obj:' + obj
  	 #console.log retObj
        #console.log 'post data:' + traverseConfigObj(obj,str)
        #webreq(@body.services.openvpnpostdata, (error, response, body) =>
  	 #      console.log body  if not error and response.statusCode is 200
	 #    @send @body
    	 #    )

#
# CloudFlash Test Application
#

    @get '/': ->
        @render index: {title: 'cloudflash', layout: no}

    @on 'set nickname': ->
        @client.nickname = @data.nickname

    @on serviceadded: ->
        @broadcast said: {nickname: @client.nickname, text: @data.text}
        @emit said: {nickname: @client.nickname, text: @data.text}

    @get '/services/:id/openvpn': ->
        var1 = @params.id
        console.log 'guid:'+var1
        #@body.service.id = var1
        @render openvpn: {title: 'cloudflash opnvpnpost', layout: no}

    @get '/delete': ->
        @render delete: {title: 'cloudflash', layout: no}

    @on servicedeleted: ->
        @broadcast said: {nickname: @client.nickname, text: @data.text}
        @emit said: {nickname: @client.nickname, text: @data.text}


    @on serviceadded1: ->
        @broadcast said: {nickname: @client.nickname, text: @data.text}
        @emit said: {nickname: @client.nickname, text: @data.text}

    @client '/index.js': ->
        @connect()

        @on serviceadded: ->
          $('#panel').append "<p>#{@data.service.name} said: #{@data.service.id}</p>"

        $ =>
#          @emit 'set nickname': {nickname: prompt 'Pick a nickname!'}

          $('#box').focus()

          $('button').click (e) ->
            $form = $(this).closest('form')
            console.log $form.attr('id')
            switch $form.attr('id')
                when 'service'
                    url = '/services'
                    data = { 'service': $form.serializeFormJSON() }
                when 'action'
                    url = '/services/'+ $form.find('input[name="id"]').val() + '/action'
                    data = { 'command': $form.find('option:selected').val() }

            json = JSON.stringify(data)
#            alert 'about to issue POST to: '+url+' with: '+json

            $.ajax
                type: "POST"
                url: url
                data: json
                contentType: "application/json; charset=utf-8"
                success: (data) =>

            e.preventDefault()


      @client '/delete.js': ->
        @connect()

        @on servicedeleted: ->
          $('#panel').append "<p>#{@data.service.id}</p>"

        $ =>

          $('#box').focus()

          $('button').click (e) =>
            $.ajax
                type: "DELETE"
                url: "/services/" + $("#id").val()
                success: (data) =>
                    @emit servicedeleted: { text: $('#box').val() }
            e.preventDefault()

      #now the data for testing is regualar JSON string
      #this is to got as encoded string
      #work in progress..
      #after recieving the encoded base64 do the decode appropriate

      @client '/openvpn.js': ->
        @connect()

        @on serviceadded1: ->
          $('#panel').append "<p>#{@data.services.openvpnpostdata} said: #{@data.service.id}</p>"

        $ =>

          $('#box').focus()

          $('button').click (e) =>
            alert 'openvpn'
            data = { 'services': $('#services').serializeFormJSON() }
            #data =  $('#openvpnpostdata').val()
            json = JSON.stringify(data)
            alert 'data:' + data
            alert 'json:' + json
            $.ajax
                type: "POST"
                url: '/services/b815bcfc-7fd2-4574-9cec-2bde565972c3/openvpn'
                data: json
                contentType: "application/json; charset=utf-8"
                success: (data) =>
                    @emit serviceadded1: { text: $('#box').val() }


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
            div ->
                p 'Create a new Service'
                form '#service', ->
                    input
                        type: 'hidden'
                        name: 'version'
                        value: '1.0'
                    p ->
                        span 'Service Name: '
                        input '#name'
                            type: 'text'
                            name: 'name'
                            value: 'at'
                    p ->
                        span 'Service Type: '
                        input '#family',
                            type: 'text'
                            name: 'family'
                            value: 'remote-access'
                    p ->
                        span 'Package URL: '
                        input '#pkgurl',
                            type: 'text'
                            name: 'pkgurl'
                            value: 'http://10.1.10.145/vpnrac-0.0.1.deb'
                    p ->
                        span 'API PATH: '
                        input '#apipath',
                            type: 'text'
                            name: 'api'
                            value: '/vpnrac'
                    button 'Send'
            div ->
                p 'Send an action to Service'
                form '#action', ->
                    p ->
                        span 'Service ID: '
                        input
                            type: 'text'
                            name: 'id'
                            value: ''
                    p ->
                        span 'Action: '
                        select name: 'action', ->
                            option value: 'start', 'Start'
                            option value: 'stop', 'Stop'
                            option value: 'restart', 'Restart'
                            option value: 'status', 'Status'
                    button 'Send'

    @view delete: ->
        doctype 5
        html ->
          head ->
            title 'CloudFlash Test Application!'
            script src: '/socket.io/socket.io.js'
            script src: '/zappa/jquery.js'
            script src: '/zappa/zappa.js'
            script src: '/jquery-json.js'
            script src: '/delete.js'
          body ->
            div id: 'panel'
            form '#services', ->
                p ->
                    span 'Service ID: '
                    input '#id'
                        type: 'text'
                        name: 'id'
                        value: 'service id'
                button 'Send'

     @view openvpn: ->
          doctype 5
          html ->
            head ->
              title 'CloudFlash Test Application!'
              script src: '/socket.io/socket.io.js'
              script src: '/zappa/jquery.js'
              script src: '/zappa/zappa.js'
              script src: '/jquery-json.js'
              script src: '/openvpn.js'
            body ->
              div id: 'panel'
              form '#services', ->
                p ->
                      span 'Service Name: '
                      input '#name'
                          type: 'text'
                          name: 'name'
                          value: 'openvpn'
                p ->
                    span 'Service Type: '
                    input '#type',
                        type: 'text'
                        name: 'type'
                        value: 'vpn'
                p ->
                      span 'Service id: '
                      input '#id'
                          type: 'text'
                          name: 'guid'
                          value: 'openvpn guid'
                p ->
                      span 'Openvpn Config: '
                      input '#configdata'
                          type: 'text'
                          name: 'openvpnpostdata'
                          value: ''
                p ->
                      input '#serviceid'
                         type: 'hidden'
                         name: 'serviceid'
                         value: "+{@params.id}+"

                button 'Send'


