util=require('util')
EventEmitter=require('events').EventEmitter
filename= "/etc/bolt/bolt.json"
fileops = require 'fileops'
http = require("http")
openssl=require('openssl-wrapper')
fs=require('fs')

boltConfigfile = '/etc/stormstack/stormbolt.conf'



class activation extends EventEmitter
    constructor:(@config)->
        util.log "activation consturctor called with "+ JSON.stringify @config

        #certificate locations
        @keyfile = "#{@config.datadir}/certs/snap.key"
        @csrfile = "#{@config.datadir}/certs/snap.csr"
        @certfile = "#{@config.datadir}/certs/snap.cert"
        @cafile = "#{@config.datadir}/certs/ca.cert"
        @metadatafile= "#{@config.datadir}/certs/meta-data.json"
        @STORMTRACKER_URL=null
        @REGKEY=null
        @HOSTNAME=null
#       @OPENSTACK_URL='http://169.254.169.254/openstack/latest/meta_data.json'
        @OPENSTACK_URL='http://192.168.122.248/latest/meta-data'
        @boltdata=null
        util.log "activation constructor called"

    isitVCG: (callback)=>
        util.log "inside isitVCG function" + @OPENSTACK_URL
        req = http.get @OPENSTACK_URL,(res) =>
            console.log "openstack metadata http response statusCode: " + res.statusCode
            res.on 'data',(chunk)=>
                metadata= JSON.parse chunk.toString()
                util.log "Metadata "+metadata
                #return false, if nexusUrl or uuid is not present in the metadata
                callback(false) unless  metadata.meta.nexusurl? or  metadata.uuid?
                @STORMTRACKER_URL=metadata.meta.nexusUrl
                @REGKEY=metadata.uuid
                util.log "StormTracker Url " + @STORMTRACKER_URL
                util.log "uuidi " + @REGKEY
                #write the metadata in file
                fileops.updateFile @metadatafile, JSON.stringify metadata

            res.on 'end',(x)=>
                console.log 'openstack metadata connection end',x
                callback(true)

        req.on 'error', (data)=>
            util.log 'Error in the openstack metadata http request: ' + data.message
            callback(false)


    isitHARDCPE: ()=>
        #Todo
        return false

    isitSOFTCPE: ()=>
        #Todo
        return false

    #discover the type of CPE -  VCG/SOFTCPE/HARDCPE
    discoverEnv: (callback)=>
        #default VCG 
        # query openstackurl, if success then VCG. if failed check the next environment mode (HW CPE).
        util.log "inside discoverEnv function"
        @isitVCG (res)=>
            util.log "isitvcg response is " + res
            if res is true
                @ENVIRONMENT='VCG'
                callback(true)
        ###
        else if isitHARDCPE() is true
            @ENVIRONMENT="HARDCPE"
            callback(true)
        else if isitSOFTCPE() is true
            @ENVIRONMENT="SOFTCPE"
            callback(true)
        else
            #unknown environment
            @ENVIRONMENT="UNKNOWN"
            callback(false)
###
    connect: (callback)=>
        util.log "connect inside"
        spawn = require('child_process').spawn
        process = spawn('/bin/ping', ['-c','1', @STORMTRACKER_URL])
        process.stdout.on 'data', (data)=>
            util.log "ping data " + data
            lines = data.toString().split('\n')
            #first line to be processed.. sample output is below
            #ping data PING 192.168.122.248 (192.168.122.248): 56 data bytes
            #64 bytes from 192.168.122.248: seq=0 ttl=64 time=0.948 ms
            array = lines[1].split(' ')
            util.log "Ping output "+ array
            if (!array[4] || array[1].indexOf('Unreachable') > -1)
                status = false
            else
                status = true
            util.log "connect status " + status
            callback(status)
   
        process.on 'error',(data)=>
            util.log "Ping error" + data
            callback(false)
        process.stderr.on 'data',(data)=>
            util.log "Ping error " + data
            callback(false)

    register: (callback)=>

        options=
            host:@STORMTRACKER_URL
            port:80
            path:'/registry/serialkey'
            headers:
                method:'GET'

        req=http.request options, (res) =>
            util.log 'Activation - Register: response status code' + res.statusCode
            util.log 'Activation - Register: response status headers' + JSON.stringify(res.headers)
            res.on 'data',(chunk)=>
                metadata= JSON.parse chunk.toString()
                util.log "Activation - Register: response data" + chunk.toString()
                @HOSTNAME = metadata.serialkey
                util.log "Activation - Register : serialkey is "+ @HOSTNAME
                #Todo .. handle the error cases, in JSON format check & writing the file etc
                fs.writeFileSync("/etc/hostname",@HOSTNAME)
                contents = ''
                contents = new Buffer(metadata.stormbolt.cabundle.data || '',metadata.stormbolt.cabundle.encoding)
                util.log "Activation - Register : writing the cabundle "+ @cafile
                #Todo .. handle the error case in writing the file
                fs.writeFileSync(@cafile,contents)
                #write the bolt config file in a file
                @boltdata=
                    "cert" : @certfile,
                    "key" : @keyfile,
                    "ca" : @cafile,
                    "remote" : metadata.stormbolt.servers,
                    "listen" :metadata.stormbolt.proxy_listen_port,
                    "local" :  metadata.stormbolt.server_port,
                    "local_forwarding_ports" :metadata.stormbolt.local_forwarding_ports,
                    "beaconParams": "#{metadata.stormbolt.beacon.interval}:#{metadata.stormbolt.beacon.retry}"
                util.log JSON.stringify @boltdata
                callback(true)
     
        req.on 'error', (err)=>
            util.log 'http request error ',err
            callback(false)
        req.end()

    getCSRData: ()=>
         csrdata=
             "name":"client1",
             "encoding":"base64",
             "data":""
         csrdata.data = fs.readFileSync(@csrfile,'base64')
         csrdata.name = @HOSTNAME
         console.log "in getCSRData"
         return csrdata

    sendCSRRequest: (callback)=>
        openssl.exec 'genrsa',{out : @keyfile ,'2048':false },(x)=>
            util.log "Activation: openssl private key generation completed, result " + x
            #Todo :  Error cases to be handled.

            openssl.exec 'req',{batch:true,new:true,nodes:true,subj:'/emailAddress=certs@clearpathnet.com/C=US/ST=CA/L=El Segundo/O=ClearPath Networks/OU=VSP/CN='+@HOSTNAME,key:@keyfile,out:@csrfile},(x)=>
                #Todo : Error cases to be handled

                util.log "Activation: openssl csr generation completed , result",x
                csrjson = @getCSRData()
                util.log "Activation: successfully created the CSR Requests for signing ",csrjson
                options1=
                    host:@STORMTRACKER_URL
                    port:80
                    path:'/signcsr'
                    method : 'POST',
                    headers:
                        'Content-Type' : 'application/json; charset=utf-8',
                        'Accept' : 'application/json',
                        'Accept-Encoding' : 'gzip,deflate,sdch',
                        'Accept-Language' : 'en-US,en;q=0.8'
                req1=http.request options1, (res) =>
                    util.log 'Activation: sendCSRRequest: response status code ' + res.statusCode
                    util.log 'Activation: sendCSRRequest: response status headers', + JSON.stringify(res.headers)

                    res.on 'data',(chunk)=>
                        metadata= JSON.parse chunk.toString()
                        util.log "Activation: CSR response data" +chunk.toString()
                        contents = ''
                        contents = new Buffer(metadata.data || '',metadata.encoding)
                        util.log "Activation: writing the signed certificate " + @certfile
                        #Todo : Error cases - response to be validated. such as JSON format, certificate empty etc
                        fs.writeFileSync(@certfile,contents)
                        callback(true)
               	req1.on 'error',(err)=>
                    util.log 'Activation : sendCSRRequest http req error',err
                    callback(false)
                req1.write(JSON.stringify(csrjson))
                req1.end()

    isItActivated: ()=>
        #check the activdated flag is true
        #return false if @activated  is false
        #check the certs folder for presence of certs files
        if (fileops.fileExistsSync(@cafile) && fileops.fileExistsSync(@keyfile) && fileops.fileExistsSync(@certfile) && fileops.fileExistsSync(boltConfigfile)) is true
            return true
        else
            return false

    start: ()=>
        util.log "activation start function called "+ JSON.stringify @config
        
        result= @isItActivated()
        if result is true
            util.log "its already activated..."
            boltContent = fileops.readFileSync boltConfigfile
            @boltconfig = JSON.parse boltContent
            this.emit "success",@boltconfig
            return
            


        @discoverEnv (result)=>
            util.log "Activation Environment is " + @ENVIRONMENT
            util.log "Activation discoverEnv result"+ result

            #failure event  if res is false
            this.emit "failure", "Unknown Environment" unless result

            @connect (result)=>
                util.log " Activation: connectivity to stormtracker, result is " + result
                    
                #failure event  if result is false
                this.emit "failure", "Failed to Connect the STORMTRACKER" unless result

                @register (result)=>
                    util.log "Activation: Registeration completed. result " + result

                    #failure event  if res is false
                    this.emit "failure", "Failed to Register with  STORMTRACKER" unless result

                    @sendCSRRequest (result)=>
                        util.log "CSR signing process over. result " + result

                        #failure event  if res is false
                        this.emit "failure", "Failed to Get the Signed certificate from STORMTRACKER" unless result

                        try
                            boltContent = fileops.readFileSync boltConfigfile
                            @boltconfig = JSON.parse boltContent
                        catch
                            @boltconfig = @boltdata
                            fileops.updateFile boltConfigfile, JSON.stringify @boltconfig
                        finally
                            this.emit "success",@boltconfig

module.exports = (args) ->
    new activation args
#module.exports = new activation args
