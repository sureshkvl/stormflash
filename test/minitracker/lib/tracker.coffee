#prerequistises
# please set up the openssl CA in the system before runs this minitracker
# refernece for setup: https://jamielinux.com/articles/2013/08/act-as-your-own-certificate-authority/

#root ca cert and key file 
ca_key_file="/home/suresh/ca/private/cakey.pem"
ca_crt_file="/home/suresh/ca/certs/ca.cert"
metadata_file = "/home/suresh/metadata.json"
myserialkey = "stormid"
clientcount=1

fs=require('fs')
openssl=require('openssl-wrapper')

#provide unique stormids "stormid_xx" for each request  :)
getmyserialkey= ->
   clientcount++
   newkey= "#{myserialkey}_#{clientcount}"
   console.log "new serial key created ",newkey
   return newkey
   

getBoltConfig= ->
    # hardcoded config
    stormbolt_config =
        {
            "servers":[],
            "server_port":443,
            "proxy_listen_port":9000,
            "local_forwarding_port":5000,
            "beacon":
                {
                    "interval":10
                    "retry":2
                }
            "loadbalance":
                {
                    "algorithm":"roundrobin"
                }
            "cabundle":
                {
                    "encoding":"base64"
                    "data":""
                }
        }
    stormbolt_config.cabundle.data = fs.readFileSync(ca_crt_file,'base64')
    return stormbolt_config


signedcert = (reqdata , callback) ->
    console.log "request - name ",reqdata.name
    console.log "request - encoding ",reqdata.encoding
    console.log "request  - data ",reqdata.data
    console.log "########################### Signing...................."
    contents = ''
    contents = new Buffer(reqdata.data || '',reqdata.encoding)
    fs.writeFileSync("/tmp/#{reqdata.name}",contents)
   
    #openssl ca -batch -keyfile /home/suresh/ca/private/cakey.pem -cert /home/suresh/ca/certs/ca.cert -notext -md sha1 -in /tmp/client2.csr -out  /tmp/client2cert.pem
  
    openssl.exec 'ca',{batch:true, keyfile : ca_key_file, cert : ca_crt_file , notext : true, in : "/tmp/#{reqdata.name}", out : "/tmp/#{reqdata.name}.signed" } , (resp)=>
        console.log "signed process over, openssl response",resp
        csrresponse=
            "name":"signed-certificate",
            "encoding":"base64",
            "data":""
        csrresponse.data=fs.readFileSync("/tmp/#{reqdata.name}.signed",'base64')
        callback(csrresponse)


@include = ->
    # discovery stuff (openstack apis)
    @get '/latest/meta-data': ->
        res=fs.readFileSync(metadata_file)
        console.log "discovery data ",res
        @send res

    # activation stuff (stormtracker apis)
    @get '/registry/serialkey': ->
        serialkey_resp =
            {
                "id":"null"
                "serialkey":""
                "lastactivation":""
                "stormbolt":{}
            }
        serialkey_resp.serialkey = getmyserialkey()
        serialkey_resp.lastactivation= new Date().toISOString()
        serialkey_resp.stormbolt = getBoltConfig()
        console.log serialkey_resp
        @send serialkey_resp

    @post '/signcsr' : ->
        console.log 'signcsr called',@body
        signedcert @body, (result) =>
            console.log 'result is ', result
            @send result

