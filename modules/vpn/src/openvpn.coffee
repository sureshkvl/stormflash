
fs = require 'fs'
path = require 'path'
exec = require('child_process').exec
validate = require('json-schema').validate


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

module.exports = class vpn
  constructor: ->
    console.log "initialized vpn"

  validateOpenvpn: ->
    console.log 'performing schema validation on incoming OpenVPN JSON'
    result = validate @body, schema
    console.log result
    return new Error "Invalid service openvpn posting!: #{result.errors}" unless result.valid
    return {"result":"success"}

  sample: ->
    console.log "sample function"
    return "true"

  serviceHandler: ->
    console.log 'in openvpn route'
    service = request.service
    config = ''
    for key, val of body
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

      exec "touch /tmp/config/#{service.description.name}/on"
#            db.main.set params.id, body, =>
      console.log "#{params.id} added to OpenVPN service configuration"
      console.log body
      return { result: true }

    catch err
      console.log "error in writing config"
      return new Error "Unable to write configuration into #{filename}!"

    #module.exports = vpn
