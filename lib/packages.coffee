##
# STORMFLASH /packages REST end-points

@include = ->
    stormflash = require('./stormflash') @include

    @get '/packages': ->
        stormflash.pkglist.list (res) =>
            console.log res
            @send res

