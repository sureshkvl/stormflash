@include = ->
    uuid = require('node-uuid')
    db   = require('dirty') '/tmp/cloudflash.db'

    webreq = require 'request'
    fs = require 'fs'
    path = require 'path'
    exec = require('child_process').exec

    #KIndly add a validation function similar to openvpn and firewall
    # validat the ID also
    # Hardcoded file name is used to get the log. Point this to 
    # right location 

    # validation is used by other modules
    #validate = require('json-schema').validate

    #db.on 'load', ->
    #    console.log 'loaded cloudflash.db'
    #    db.forEach (key,val) ->
    #        console.log 'found ' + key

    
    @get '/services/:id/openvpn/server': ->
                key = []
                val = []
                openvpn = '{ "openvpn" : {'
                connected = ' "connected" : [ '
                i = 1
                for line in fs.readFileSync("openvpn-status.log").toString().split '\n'
                        if line=='ROUTING TABLE'
                                break
                        if i<=2
                                i++
                                continue
                        if 3==i
                                for word in line.split ','
                                        key.push word
                        else if i>=4
                                val = []
                                for word in line.split ','
                                        val.push word
                        i++
                        j = 0
                        keyval ='{'
                        while j < 5
                                if val[j]
                                        pair = '"' + key[j] + '"' + " : " + '"' + val[j] + '"'
                                        keyval = keyval + pair 
                                        if j < 4
                                                keyval = keyval + ','
                                j++
                        keyval = keyval + ' }'
                        if val[0]
                                connected = connected + keyval
                connected = connected + ']'
                openvpn = openvpn + connected + '} }'
                @send openvpn
