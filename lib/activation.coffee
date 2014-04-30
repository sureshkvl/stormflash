util=require('util')
EventEmitter=require('events').EventEmitter
filename= "/etc/bolt/bolt.json"
fileops = require 'fileops'
http = require("http")
ping = require("net-ping")
openssl=require('openssl-wrapper')
fs=require('fs')

# certificate file locations
keyfile = '/etc/stormflash/snap.key'
csrfile = '/etc/stormflash/snap.csr'
certfile = '/etc/stormflash/snap.cert'
cafile = '/etc/stormflash/ca.cert'

class activation extends EventEmitter
    constructor:->
        @ACTIVATION_ENV=null
        @NEXUS_SERVER=null
        @REGKEY=1111
        @HOSTNAME=null
        @SOFTCPE_NEXUSFILE='/etc/nexus'
        @VCG_NEXUSFILE='/etc/nexus_openstack'
        @OPENSTACK_URL='http://169.254.169.254/openstack/latest/meta_data.json'
        console.log 'activation : constructor called'
        @boltdata=null

    register: (callback)=>
        options=
            host:"192.168.122.248"
            port:5555
            path:'/registry/serialkey'
            headers:
                method:'GET'

        req=http.request options, (res) =>
            console.log 'postregister: response status code', res.statusCode
            console.log 'postregister: response status headers',JSON.stringify(res.headers)
            res.on 'data',(chunk)=>
                metadata= JSON.parse chunk.toString()
                console.log "response data",chunk.toString()
                @HOSTNAME = metadata.serialkey
                console.log "HOSTNAME is ",@HOSTNAME
                contents = ''
                contents = new Buffer(metadata.stormbolt.cabundle.data || '',metadata.stormbolt.cabundle.encoding)
                fs.writeFileSync(cafile,contents)
                callback(true)
     
        req.on 'error', (err)=>
            console.log 'http request error ',err
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
            console.log "openssl private key generation completed, result " , x
            openssl.exec 'req',{batch:true,new:true,nodes:true,subj:'/emailAddress=certs@clearpathnet.com/C=US/ST=CA/L=El Segundo/O=ClearPath Networks/OU=VSP/CN='+@HOSTNAME,key:keyfile,out:csrfile},(x)=>
                console.log "openssl csr generation completed , result",x
                csrjson = @getCSRData()
                console.log "successfully created the CSR Requests",csrjson
                options1=
                    host:"192.168.122.248"
                    port:5555
                    path:'/signcsr'
                    method : 'POST',
                    headers:
                        'Content-Type' : 'application/json; charset=utf-8',
                        'Accept' : 'application/json',
                        'Accept-Encoding' : 'gzip,deflate,sdch',
                        'Accept-Language' : 'en-US,en;q=0.8'
                req1=http.request options1, (res) =>
                    console.log 'sendCSRRequest: response status code', res.statusCode
                    console.log 'sendCSRRequest: response status headers',JSON.stringify(res.headers)

                    res.on 'data',(chunk)=>
                        console.log 'data', chunk
                        metadata= JSON.parse chunk.toString()
                        console.log "response data",chunk.toString()
                        contents = ''
                        contents = new Buffer(metadata.data || '',metadata.encoding)
                        fs.writeFileSync(certfile,contents)
                        callback(true)
               	req1.on 'error',(err)=>
                    console.log 'http req error',err
                req1.write(JSON.stringify(csrjson))
                req1.end()

    start: ()=>
        @register (x)=>   
            console.log "registeration over",x
            @sendCSRRequest (x)=>
                console.log "CSR signing process over",x

module.exports = new activation
