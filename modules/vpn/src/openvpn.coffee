
fs = require 'fs'
path = require 'path'
exec = require('child_process').exec
validate = require('json-schema').validate
url = require("url")

dbvpn =
    main: require('dirty') '/tmp/openvpn.db'
    user: require('dirty') '/tmp/openvpnusers.db'

    # testing openvpn validation with test schema
clientschema =
    name: "openvpn"
    type: "object"
    additionalProperties: false
    properties:
        pull:                {"type":"boolean", "required":true}
        'tls-client':        {"type":"boolean", "required":true}
        dev:                 {"type":"string", "required":true}
        proto:               {"type":"string", "required":true}
        ca:                  {"type":"string", "required":true}
        dh:                  {"type":"string", "required":true}
        cert:                {"type":"string", "required":true}
        key:                 {"type":"string", "required":true}
        remote:              {"type":"string", "required":true}
        cipher:              {"type":"string", "required":false}
        'tls-cipher':        {"type":"string", "required":false}
        route:
            items: { type: "string" }
        push:
            items: { type: "string" }
        'persist-key':       {"type":"boolean", "required":false}
        'persist-tun':       {"type":"boolean", "required":false}
        status:              {"type":"string", "required":false}
        'comp-lzo':          {"type":"string", "required":false}
        verb:                {"type":"number", "required":false}
        mlock:               {"type":"boolean", "required":false}

serverschema =
    name: "openvpn"
    type: "object"
    additionalProperties: false
    properties:
        port:                {"type":"number", "required":true}
        dev:                 {"type":"string", "required":true}
        proto:               {"type":"string", "required":true}
        ca:                  {"type":"string", "required":true}
        dh:                  {"type":"string", "required":true}
        cert:                {"type":"string", "required":true}
        key:                 {"type":"string", "required":true}
        server:              {"type":"string", "required":true}
        'script-security':   {"type":"string", "required":false}
        multihome:           {"type":"boolean", "required":false}
        management:          {"type":"string", "required":false}
        cipher:              {"type":"string", "required":false}
        'tls-cipher':        {"type":"string", "required":false}
        auth:                {"type":"string", "required":false}
        topology:            {"type":"string", "required":false}
        'route-gateway':     {"type":"string", "required":false}
        'client-config-dir': {"type":"string", "required":false}
        'ccd-exclusive':     {"type":"boolean", "required":false}
        'client-to-client':  {"type":"boolean", "required":false}
        route:
            items: { type: "string" }
        push:
            items: { type: "string" }
        'max-clients':       {"type":"number", "required":false}
        'persist-key':       {"type":"boolean", "required":false}
        'persist-tun':       {"type":"boolean", "required":false}
        status:              {"type":"string", "required":false}
        keepalive:           {"type":"string", "required":false}
        'comp-lzo':          {"type":"string", "required":false}
        sndbuf:              {"type":"number", "required":false}
        rcvbuf:              {"type":"number", "required":false}
        txqueuelen:          {"type":"number", "required":false}
        'replay-window':     {"type":"string", "required":false}
        verb:                {"type":"number", "required":false}
        mlock:               {"type":"boolean", "required":false}

siteschema =
    name: "openvpn"
    type: "object"
    additionalProperties: false
    properties:
        id:    { type: "string", required: true }
        commonname: { type: "string", required: true }
        push:
          items: { type: "string" }

userschema =
    name: "openvpn"
    type: "object"
    additionalProperties: false
    properties:
        id:    { type: "string", required: true }
        email: { type: "string", required: true }
        push:
          items: { type: "string" }



module.exports = class vpn
  constructor: (@request, @body, @params) ->
    console.log "initialized vpn"
    @serverschema = serverschema
    @clientschema = clientschema
    @siteschema = siteschema
    @userschema = userschema

   

  # validateOpenvpn: Validates if a given POST openvpn service request json has valid schema. 
  # Returns JSON with 'success' as value to 'result' key Or an Error message.
  validateschema: (schema) ->
    console.log 'performing schema validation on incoming OpenVPN JSON'
    return new Error "No body as input" unless @body
    result = validate @body, schema
    console.log result
    return new Error "Invalid service openvpn posting!: #{result.errors}" unless result.valid
    return {"result":"success"}


  sample: ->
    console.log "sample function"
    return "true"

  # createCCDConfig: Creates a file under ccd directory with given filename and sends sync to the service.
  # Returns a JSON on success with key as 'result' and 'success' as its value. 
  # On Error, sends an error message.
  createCCDConfig: (serviceName, filename) ->
    config = ''
    for key, val of @body
      switch (typeof val)
        when "object"
          if val instanceof Array
            for i in val
              config += "#{key} #{i}\n" if key is "iroute"
              config += "#{key} \"#{i}\"\n" if key is "push"

    console.log "config test: " + config
    filename = "/config/openvpn/ccd/#{filename}"
    try
      console.log "write user config to #{filename}..."
      dir = path.dirname filename
      unless path.existsSync dir
        exec "mkdir -p #{dir}", (error, stdout, stderr) =>
          unless error
            fs.writeFileSync filename, config
      else
        fs.writeFileSync filename, config

      #TODO: For unit testing till svc is part of cloudflash we use service openvpn restart
      #exec "svcs #{servicename} sync"
      exec "service openvpn restart"
      dbvpn.user.set @body.id, @body, =>
        console.log "#{filename} added to OpenVPN service configuration"
      return {"result":"success"}
    catch err
      return new Error "Unable to write configuration into #{filename}!"

  createOpenvpnConfig: (filename) ->
    console.log "in createopenvpnConfig"
    config = ''
    for key, val of @body
      switch (typeof val)
        when "object"
          if val instanceof Array
            for i in val
              config += "#{key} #{i}\n" if key is "route"
              config += "#{key} \"#{i}\"\n" if key is "push"
        when "number", "string"
          config += key + ' ' + val + "\n"
        when "boolean"
          config += key + "\n"

    console.log "config: " + config
    #filename = __dirname+'/services/'+varguid+'/openvpn/server.conf'
    filename = "/config/openvpn/#{filename}"
    try
      console.log "write openvpn config to #{filename}..."
      dir = path.dirname filename
      unless path.existsSync dir
        console.log 'no path exists'
        exec "mkdir -p #{dir}", (error, stdout, stderr) =>
          unless error
            console.log 'created path'
            fs.writeFileSync filename, config
      else
        fs.writeFileSync filename, config
        console.log 'wrote config file'

      exec "touch /config/openvpn/on"
      console.log "params " + @params.id
      console.log "body " + @body
      dbvpn.main.set @params.id, @body,  =>
        console.log "#{@params.id} added to OpenVPN service configuration"
      return {"result":"success"}

    catch err
      return new Error "Unable to write configuration into #{filename}!"

  # serviceHandler: Main function of this module which gets called by external applications to 
  # route openvpn API endpoints.
  # On Error, returns error message. On Successful handling, sends appropriate JSON object with success.
  serviceHandler:  ->
    pathname = url.parse(@request.url).pathname
    console.log "pathname in vpn: " + pathname
    console.log "req method in vpn: " + @request.method
    reqMethod = @request.method
    
    switch reqMethod
      when "POST"
        switch pathname
          when "/services/#{@params.id}/openvpn"
            console.log 'in openvpn route in src'
            res = @validateschema(serverschema)
            console.log 'validate res:' + res
            return @createOpenvpnConfig("server.conf") unless res instanceof Error
            return new Error "Invalid JSON object"

          when "/services/#{@params.id}/openvpn/client"
            console.log 'in openvpn route in src'
            res = @validateschema(clientschema)
            console.log 'validate res:' + res
            return @createOpenvpnConfig("client.conf") unless res instanceof Error
            return new Error "Invalid JSON object"
    
          when "/services/#{@params.id}/openvpn/users"
            console.log 'in openvpn user route'
            service = @request.service
            res = @validateschema(userschema)
            console.log res
            return @createCCDConfig(service.description.name, "#{@body.email}") unless res instanceof Error
            return new Error "Invalid JSON object"

          when "/services/#{@params.id}/openvpn/sites"
            console.log 'in openvpn site post'
            service = @request.service
            res = @validateschema(siteschema)
            if res instanceof Error
              return new Error "Invalid JSON object"
            return @createCCDConfig(service.description.name, "#{@body.commonname}", @body)

          else return new Error "No method found"

      when "GET"
        switch pathname
          when "/services/#{@params.id}/openvpn"
            console.log 'in openvpn route in src get' + @request.service.id
            res =
              id: @request.service.id
              users: []
              connections: []

            dbvpn.user.forEach (key,val) ->
              console.log 'found ' + key
              res.users.push val

            # TODO: should retrieve the openvpn configuration and inspect "management" and "status" property

            Lazy = require 'lazy'
            status = new Lazy
            status
                .lines
                .map(String)
                .filter (line) ->
                    not (
                        /^OpenVPN/.test(line) or
                        /^Updated/.test(line) or
                        /^Common/.test(line) or
                        /^ROUTING/.test(line) or
                        /^Virtual/.test(line) or
                        /^GLOBAL/.test(line) or
                        /^UNDEF/.test(line) or
                        /^END/.test(line) or
                        /^Max bcast/.test(line))
                .map (line) ->
                    console.log "lazy: #{line}"
                    return line.trim().split ','
                .forEach (fields) ->
                    switch fields.length
                        when 5
                            res.connections.push {
                                cname: fields[0]
                                remote: fields[1]
                                received: fields[2]
                                sent: fields[3]
                                since: fields[4]
                            }
                        when 4
                            for conn in res.connections
                                if conn.cname is fields[1]
                                    conn.ip = fields[0]
                .join =>
                    console.log res
                    return res

            console.log "checking for live connections..."

            # OPENVPN MGMT API v1
            net = require 'net'
            conn = net.connect 2020, '127.0.0.1', ->
                console.log 'connection to openvpn mgmt successful!'
                response = ''
                @setEncoding 'ascii'
                @on 'prompt', =>
                    @write "status\n"
                @on 'response', =>
                    console.log "response: #{response}"
                    status.emit 'end'
                    @write "exit\n"
                    @end
                @on 'data', (data) =>
                    console.log "read: "+data+"\n"
                    if /^>/.test(data)
                        @emit 'prompt'
                    else
                        response += data
                        status.emit 'data',data
                        if /^END$/gm.test(response)
                            @emit 'response'
                @on 'end', =>
                    console.log 'connection to openvpn mgmt ended!'
                    status.emit 'end'
                    @end
 
            # When we CANNOT make a connection to OPENVPN MGMT port, we fallback to checking file
            conn.on 'error', (error) ->
                console.log error
                statusfile = "/var/log/server-status.log" # hard-coded for now...

                console.log "failling back to processing #{statusfile}..."
                #statusfile = "openvpn-status.log" # hard-coded for now...
                stream = fs.createReadStream statusfile, encoding: 'utf8'
                stream.on 'open', ->
                    console.log "sending #{statusfile} to lazy status..."
                    stream.on 'data', (data) ->
                        status.emit 'data',data
                    stream.on 'end', ->
                        status.emit 'end'

                stream.on 'error', (error) ->
                    console.log error
                    status.emit 'end'
          else return new Error "No method found"

      when "DELETE"
        switch pathname
          when "/services/#{@params.id}/openvpn/users/#{@params.user}"
            console.log 'In openvpn deleteuser : ' + @params
            userid = @params.user
            entry = dbvpn.user.get userid
            filename = "/config/openvpn/ccd/#{entry.email}"
            throw new Error "user does not exist!" unless entry

            try
                console.log "removing user config on #{filename}..."
                path.exists filename, (exists) =>
                    throw new Error "user is already removed!" unless exists

                    fs.unlink filename, (err) =>
                        throw err if err

                        db.user.rm userid, =>
                            console.log "removed VPN user ID: #{userid}"
                        return { deleted: true }
            catch err
                return new Error "Unable to remove user ID: #{userid} due to #{err}"


