##
# STORMFLASH /packages REST end-points

@include = ->
    stormflash = require('./stormflash') @include
    validate = require('json-schema').validate
    schema =
        name: "personality"
        type: "object"
        required: true
        properties:
            name : { type: "string", "required": true }
            version : { type: "string", "required": true }
            source : { type: "string", "required": true }

    @post '/packages': ->
        console.log JSON.stringify @body
        result = validate @body, schema
        console.log result
        stormflash.pkglist.install @body, (res) =>
            console.log res
            @send res

    @get '/packages': ->
        stormflash.pkglist.list (res) =>
            console.log res
            @send res

