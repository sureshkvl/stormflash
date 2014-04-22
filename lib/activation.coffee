util=require('util')
EventEmitter=require('events').EventEmitter
filename= "/etc/bolt/bolt.json"
fileops = require 'fileops'
http = require("http")
ping = require("net-ping")
openssl=require('openssl-wrapper')

class activation extends EventEmitter
    constructor:->
        @ACTIVATION_ENV=null
        @NEXUS_SERVER=null
        @REGKEY=null
        @HOSTNAME=null
        @SOFTCPE_NEXUSFILE='/etc/nexus'
        @VCG_NEXUSFILE='/etc/nexus_openstack'
        @OPENSTACK_URL='http://169.254.169.254/openstack/latest/meta_data.json'
        console.log 'activation : constructor called'
        @boltdata=null

    start: ()->
    ## The below code, is just a hack for bolt integreation testing till activation module implementation.
        setTimeout(()=>
            console.log 'inside setinterval - start'
            data=null
            fileops = require("fileops")
            res =  fileops.fileExistsSync filename
            unless res instanceof Error
                boltContent = fileops.readFileSync filename
                @boltdata = JSON.parse boltContent
                console.log "success event : data: ",data
                this.emit "success",@boltdata
            else
                return new Error "File does not exist! " + res
                console.log "failed event "
                this.emit "failure","file not found"
        5000)
    getBoltData: ()->
        console.log "activation: getBoltData is called"
        return @boltdata

    ## hack ends here
###multiline comment.
#The below code is not yet complete..this is for phase2.. will be removed once stormtracker implementation and API details are clear
		discover()
		connect()
		activate()




	discover:->
		# SOFT-CPE  : /etc/nexus file will have the nexus server details
		# VCG 	    : download the meta-data from the openstack
		# HARD-CPE  : read the special utiltiy cmd and populate

		#SOFT-CPE routine
		res =  fileops.fileExistsSync @SOFTCPE_NEXUSFILE
		unless res instanceof Error
			nexusContent = fileops.readFileSync @SOFTCPE_NEXUSFILE
			data = JSON.parse nexusContent
			@ACTIVATION_ENV="SOFT-CPE"
			console.log "nexus file contents : ",data				
			return
		else
			console.log "Not a SOFT-CPE"
	
		#VCG routine
		#download the metadata from openstack
		#activation script equivalent code
		#NEXUS_SERVER=`curl -m 5 -s http://169.254.169.254/openstack/latest/meta_data.json 2>/dev/null`
		req = http.get "http://169.254.169.254/openstack/latest/meta_data.json",(res) =>
			console.log 'http response statusCode: ' + res.statusCode
			res.on 'data',(chunk)=>
				metadata= JSON.parse chunk.toString()
				@NEXUS_SERVER=metadata.meta.nexusUrl
				@REGKEY=metadata.uuid				
				console.log metadata
				console.log 'nexusUrl' , @NEXUS_SERVER
				console.log 'uuid' ,@REGKEY
				return
			
			res.on 'end',(x)=>
				console.log 'http meta data response connection end',x
		# error cases to be added  http timeout, http error etc.		

		#HARD-CPE routine
			# to be done
	connect: ()->
		pingSession=ping.createSession()
		pingSession.pingHost @NEXUS_SERVER,(error,target)=>
			if (error)
				console.log "Ping Error : ",error
				return false
			else
				console.log " Ping Success :",target
				return true	

	postregister: ()->

		#register json data strucutre
		registerdata=
			{
			'uuid':@REGKEY
			}

		#http headers and options 
		options=
			host:@NEXUS_SERVER
			port:8080
			path:'/Register'
			headers:
				'Content-Type':'application/json'
				method:'POST'

		#trigger the http request
		req=http.request options, (res) =>
			console.log 'postregister: response status code', res.statusCode
			console.log 'postregister: response status headers',JSON.stringify(res.headers)
			res.on 'data',(chunk)=>
				console.log "response data",chunk.toString()
				# response to be handled here
				# read the hostname and 
				@HOSTNAME='stormid-1'

		#http request call is failed .. handling the error	
		req.on 'error', (err)=>
			console.log 'http request error ',err
			return false

		#writing the data in http request handler	
		req.write(JSON.stringify(jsondata))
		console.log " successfully written the data"
		req.end()

	postactivate: ()->
               #activate json data strucutre
		activatedata=
			{
			'uuid':@REGKEY
			}

		#http headers and options
		options=
			host:@NEXUS_SERVER
			port:8080
			path:'/Register'
			headers:
				'Content-Type':'application/json'
			method:'POST'

		#trigger the http request
		req=http.request options, (res) =>
			console.log 'postregister: response status code', res.statusCode
			console.log 'postregister: response status headers',JSON.stringify(res.headers)
			res.on 'data',(chunk)=>
				console.log "response data",chunk.toString()
				# response to be handled here
				# read the hostname and
				@HOSTNAME='stormid-1'
			#http request call is failed .. handling the error
		req.on 'error', (err)=>
			console.log 'http request error ',err
			return false
		#writing the data in http request handler
		req.write(JSON.stringify(jsondata))
		console.log " successfully written the data"
		req.end()




	activate :()->
		#doRegister
		if postregister() is true
			# no HOSTNAME till now. So using REGKEY in CN.
			openssl.exec 'genrsa',{out:'/tmp/snap.key','2048':false},(x)=>
				openssl.exec 'req',{batch:true,new:true,nodes:true,subj:'/emailAddress=certs@clearpathnet.com/C=US/ST=CA/L=El Segundo/O=ClearPath Networks/OU=VSP/CN='+@HOSTNAME,key:'/tmp/snap.key',out:'/tmp/snap.csr'},(x)=>
					postactivate()

		
	print: ()->
 		console.log 'activation - print fn'


###

module.exports = new activation
