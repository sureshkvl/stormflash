
fs = require 'fs'
path = require 'path'
exec = require('child_process').exec
validate = require('json-schema').validate
url = require("url")

db =
    main: require('dirty') '/tmp/openvpn.db'
    user: require('dirty') '/tmp/openvpnusers.db'

    # testing openvpn validation with test schema
schema =
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

siteSchema=
    name: "openvpn"
    type: "object"
    additionalProperties: false
    properties:
        id:    { type: "string", required: true }
        commonname: { type: "string", required: true }
        push:

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
  constructor: (@request,@body,@params,@db) ->
    console.log "initialized vpn"

  # validateOpenvpn: Validates if a given POST openvpn service request json has valid schema. 
  # Returns JSON with 'success' as value to 'result' key Or an Error message.
  validateOpenvpn: ->
    console.log 'performing schema validation on incoming OpenVPN JSON'
    result = validate @body, schema
    console.log result
    return new Error "Invalid service openvpn posting!: #{result.errors}" unless result.valid
    return {"result":"success"}


  # validateOpenvpnUser: Validates if a given POST openvpn service request json has valid schema. 
  # Returns JSON with 'success' as value to 'result' key Or an Error message.
  validateOpenvpnUser: ->
    console.log 'performing schema validation on incoming user validation JSON'
    result = validate @body, userschema.properties
    console.log result
    return  new Error "Invalid service openvpn posting!: #{result.errors}" unless result.valid
    return {"result":"success"}

  # validateOpenvpnSite: Validates if a given POST openvpn service request json has valid schema. 
  # Returns JSON with 'success' as value to 'result' key Or an Error message.
  validateOpenvpnSite: ->
    console.log 'performing schema validation on incoming site validation JSON'
    result = validate @body, siteSchema.properties
    console.log result
    return  new Error "Invalid service openvpn posting!: #{result.errors}" unless result.valid
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

    try
      console.log "write user config to #{filename}..."
      dir = path.dirname filename
      unless path.existsSync dir
        exec "mkdir -p #{dir}", (error, stdout, stderr) =>
        unless error
          fs.writeFileSync filename, config
        else
          fs.writeFileSync filename, config

        exec "svcs #{servicename} sync"

        console.log "#{filename} added to OpenVPN service configuration"
        console.log @body
        return {"result":"success"}
    catch err
      return new Error "Unable to write configuration into #{filename}!"

  # serviceHandler: Main function of this module which gets called by external applications to 
  # route openvpn API endpoints.
  # On Error, returns error message. On Successful handling, sends appropriate JSON object with success.
  serviceHandler: ->
    pathname = url.parse(@request.url).pathname
    console.log "pathname in vpn: " + pathname

    res = validateOpenvpn()
    if res instanceof Error
      return res
    switch pathname
      when "/services/#{@params.id}/openvpn"
        console.log 'in openvpn route in src'
        service = @request.service
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
        filename = '/tmp/config/openvpn/server.conf'
        try
          console.log "write openvpn config to #{filename}..."
          dir = path.dirname filename
          unless path.existsSync dir
            console.log 'no path exists'
            exec "mkdir -p #{dir}", (error, stdout, stderr) =>
              unless error
                console.log 'created path and wrote config'
                fs.writeFileSync filename, config
          else
            fs.writeFileSync filename, config
            console.log 'wrote config file'

          exec "touch /tmp/config/openvpn/on"
          #db.main.set @params.id, @body, =>
          console.log "#{@params.id} added to OpenVPN service configuration"
          return {"result":"success"}

        catch err
          console.log "error in writing config"
          return new Error "Unable to write configuration into #{filename}!"
    
      when "/services/#{@params.id}/openvpn/users"
        console.log 'in openvpn user route'
        service = @request.service
        res = validateOpenvpnUser()
        unless res instanceof Error
          return @createCCDConfig(service.description.name, "/config/openvpn/ccd/#{@body.email}", @body)
        else
          return res


      when "/serivces/#{@params.id}/openvpn/sites"
        console.log 'in openvpn site post'
        service = @request.service
        res = validateOpenvpnSite()
        unless res instanceof Error
          return @createCCDConfig(service.description.name, "/config/openvpn/ccd/#{@body.commonname}", @body)
        else
          return res

      else return new Error "No method found"

