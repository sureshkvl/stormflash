##
# STORMFLASH /environment REST end-points

@include = ->
    stormflash = require('./stormflash') @include

    @get '/': ->
        stormflash.environment.list (res) =>
            console.log res
            @send res

    @get '/environment': ->
        stormflash.environment.list (res) =>
            console.log res
            @send res
    @get '/bolt': ->
       x= require('./activation').getBoltData()
       console.log x
       @send x


