util=require('util')
EventEmitter=require('events').EventEmitter
filename= "/etc/bolt/bolt.json"
fileops = require 'fileops'
http = require("http")
openssl=require('openssl-wrapper')
fs=require('fs')

# certificate file locations
keyfile = '/etc/stormflash/certs/snap.key'
csrfile = '/etc/stormflash/certs/snap.csr'
certfile = '/etc/stormflash/certs/snap.cert'
cafile = '/etc/stormflash/certs/ca.cert'

# global def



class activation extends EventEmitter
    constructor:()->
        @ACTIVATION_ENV=null
        @STORMTRACKER_URL=null
        @REGKEY=1111
        @HOSTNAME=null

        @SOFTCPE_NEXUSFILE='/etc/nexus'
        @VCG_NEXUSFILE='/etc/nexus_openstack'
#        @OPENSTACK_URL='http://169.254.169.254/openstack/latest/meta_data.json'
        @OPENSTACK_URL='http://192.168.122.248/latest/meta-data'
        
        @boltdata=null
        util.log "activation constructor called"




    isitVCG: (callback)=>
        util.log "inside isitVCG function" + @OPENSTACK_URL
        req = http.get @OPENSTACK_URL,(res) =>
            console.log "openstack metadata http response statusCode: " + res.statusCode
            res.on 'data',(chunk)=>
                metadata= JSON.parse chunk.toString()
                @STORMTRACKER_URL=metadata.meta.nexusUrl
                @REGKEY=metadata.uuid
                util.log metadata
                util.log "StormTracker Url " + @STORMTRACKER_URL
                util.log "uuidi " + @REGKEY
                #write the metadata in file
                fileops.updateFile "/etc/stormflash/vcg-metadata", metadata
                #callback(true)
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
            return true
        else if isitSOFTCPE() is true
            @ENVIRONMENT="SOFTCPE"
            return true
        else
            #unknown environment
            return false
###
    connect: (callback)=>
        util.log "connect inside"
        cp = require('child_process')
        process = cp.spawn('/bin/ping', ['-c','1', @STORMTRACKER_URL])
        process.stdout.on 'data', (data)=>
            util.log "ping data " + data
            lines = data.toString().split('\n')
            #first line to be processed.. sample output is below
            #ping data PING 192.168.122.248 (192.168.122.248): 56 data bytes
            #64 bytes from 192.168.122.248: seq=0 ttl=64 time=0.948 ms
            array = lines[1].split(' ')
            util.log array
             
            if (!array[4] || array[1].indexOf('Unreachable') > -1)
                status = false
            else
                status = true
            util.log "connect status " + status
            callback(status)

        process.on 'error',(data)=>
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
                contents = ''
                contents = new Buffer(metadata.stormbolt.cabundle.data || '',metadata.stormbolt.cabundle.encoding)
                util.log "Activation - Register : writing the cabundle "+ cafile
                fs.writeFileSync(cafile,contents)
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
         csrdata.data = fs.readFileSync(csrfile,'base64')
         csrdata.name = @HOSTNAME
         console.log "in getCSRData"
         return csrdata

    sendCSRRequest: (callback)=>
        openssl.exec 'genrsa',{out : keyfile ,'2048':false },(x)=>
            util.log "Activation: openssl private key generation completed, result " + x
            openssl.exec 'req',{batch:true,new:true,nodes:true,subj:'/emailAddress=certs@clearpathnet.com/C=US/ST=CA/L=El Segundo/O=ClearPath Networks/OU=VSP/CN='+@HOSTNAME,key:keyfile,out:csrfile},(x)=>
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
                        util.log "Activation: writing the signed certificate " + certfile
                        fs.writeFileSync(certfile,contents)
                        callback(true)
               	req1.on 'error',(err)=>
                    util.log 'Activation : sendCSRRequest http req error',err
                    callback(false)
                req1.write(JSON.stringify(csrjson))
                req1.end()

    start: ()=>
        util.log "activation - start function called"
        @discoverEnv (res)=>
            util.log "Activation Environment is " + @ENVIRONMENT
            util.log "Activation discoverEnv result"+ res
            @connect (result)=>
                util.log " Activation: connectivity to stormtracker, result is " + result
                @register (x)=>
                    util.log "Activation: Registeration completed. result " + x
                    @sendCSRRequest (x)=>
                        util.log "CSR signing process over. result " + x
                        #Todo:  bolt configuration taken from file.. to be modified to use the recevied infor from tracker
                        boltContent = fileops.readFileSync "/etc/bolt/bolt.json"
                        @boltdata = JSON.parse boltContent
                        this.emit "success",@boltdata
#                else
#                    util.log " STORMTRACKER is not reachable"
module.exports = new activation
