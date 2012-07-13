{@app} = require('zappajs') ->
    @configure =>
      @use 'bodyParser', 'methodOverride', @app.router, 'static'
      @set 'basepath': '/v1.0'

    @configure
      development: => @use errorHandler: {dumpExceptions: on, showStack: on}
      production: => @use 'errorHandler'

    @enable 'serve jquery', 'minify'

    @include 'services'
    @include 'firewall'

    @include 'openvpn'
    @include 'openvpnlog'

    @get '/': ->
        @render index: {title: 'cloudflash', layout: no}

    @on 'set nickname': ->
        @client.nickname = @data.nickname

    @on serviceadded: ->
        @broadcast said: {nickname: @client.nickname, text: @data.text}
        @emit said: {nickname: @client.nickname, text: @data.text}

    @get '/delete': ->
        @render delete: {title: 'cloudflash', layout: no}

    @on servicedeleted: ->
        @broadcast said: {nickname: @client.nickname, text: @data.text}
        @emit said: {nickname: @client.nickname, text: @data.text}

    @on openvpnadded: ->
        @broadcast said: {nickname: @client.nickname, text: @data.text}
        @emit said: {nickname: @client.nickname, text: @data.text}

    @on firewalladded: ->
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
            #console.log $form.attr('id')            
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

      
      #Have to implement encoded and decoding
      #work in progress..
      #after recieving the encoded base64 do the decode appropriate

      @client '/openvpn.js': ->
        @connect()

        @on openvpnadded: ->
          $('#panel').append "<p>#{@data.services.openvpn} said: #{@data.service.id}</p>"

        $ =>

          $('#box').focus()

          $('button').click (e) =>             
             json =  $("#configdata").val()             
             id = $("#id").val()             
             unless id is " " and id is "undefined"           
             	 $.ajax
                  type: "POST"
                  url: '/services/'+id+'/openvpn'
                  data: json
                  contentType: "application/json; charset=utf-8"
                  success: (data) =>
                      @emit openvpnadded: { text: $('#box').val() }


               e.preventDefault()

       @client '/firewall.js': ->
        @connect()

        @on firewalladded: ->
          $('#panel').append "<p>#{@data.services.firewall} said: #{@data.service.id}</p>"

        $ =>

          $('#box').focus()

          $('button').click (e) =>             
             json =  $("#configdata").val()             
             id = $("#id").val()
             
             unless id is " " and id is "undefined"           
             	 $.ajax
                  type: "POST"
                  url: '/services/'+id+'/firewall'
                  data: json
                  contentType: "application/json; charset=utf-8"
                  success: (data) =>
                      @emit firewalladded: { text: $('#box').val() }


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
               
                button 'Send'

      @view firewall: ->
          doctype 5
          html ->
            head ->
              title 'CloudFlash Test Application!'
              script src: '/socket.io/socket.io.js'
              script src: '/zappa/jquery.js'
              script src: '/zappa/zappa.js'
              script src: '/jquery-json.js'
              script src: '/firewall.js'
            body ->
              div id: 'panel'
              form '#services', ->
                p ->
                      span 'Service Name: '
                      input '#name'
                          type: 'text'
                          name: 'name'
                          value: 'firewall'
                p ->
                    span 'Service Type: '
                    input '#type',
                        type: 'text'
                        name: 'type'
                        value: 'iptables'
                p ->
                      span 'Service id: '
                      input '#id'
                          type: 'text'
                          name: 'guid'
                          value: 'firewall guid'
                p ->
                      span 'Firewall Config: '
                      input '#configdata'
                          type: 'text'
                          name: 'firewallpostdata'
                          value: ''
               
                button 'Send'

