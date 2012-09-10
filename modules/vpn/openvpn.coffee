
fs = require 'fs'
path = require 'path'
exec = require('child_process').exec
handler = (request, body, params, db)  ->
        console.log 'in openvpn route'
    #@post '/services/:id/openvpn', loadService, validateOpenvpn, ->
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



module.exports = handler
