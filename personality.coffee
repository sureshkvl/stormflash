@include = ->

    fs = require 'fs'
    validate = require('json-schema').validate
    exec = require('child_process').exec

    schema =
        name: "personality"
        type: "object"
        items:
            type: "object"
            additionalProperties: false
            properties:
                path:     { type: "string", required: true }
                contents: { type: "string", required: true }
                postxfer: { type: "string" }

    @post '/personality': ->
        console.log 'performing schema validation on incoming service JSON'

        console.log @body

        result = validate @body, schema
        console.log result
        return @next new Error "Invalid personality posting!: #{result.errors}" unless result.valid

        for p in @body.personality
            console.log p
            do (p) ->
                console.log "write personality to #{p.path}..."
                fs.writeFile p.path, new Buffer(p.contents || '',"base64"), ->
                    return
                    # this feature currently disabled DO NOT re-enable!
                    if p.postxfer?
                        exec p.postxfer, (error, stdout, stderr) ->
                            console.log "issuing '#{p.postxfer}'... stderr: #{stderr}" if error
                            console.log "issuing '#{p.postxfer}'... stdout: #{stdout}" unless error

        @send { result: 'success' }
