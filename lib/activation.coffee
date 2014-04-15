util=require('util')
EventEmitter=require('events').EventEmitter
filename= "/etc/bolt/bolt.json"

class activation extends EventEmitter
	constructor:->
		console.log 'activation : constructor called'
		data='temp'
		#this.emit "success",data
	start: ()->
	## The below code, is just a hack for bolt integreation testing till activation module implementation.
		setTimeout(()=>
			console.log 'inside setinterval - start'
			data=null
			fileops = require("fileops")
			res =  fileops.fileExistsSync filename
			unless res instanceof Error
				boltContent = fileops.readFileSync filename
				data = JSON.parse boltContent
				console.log "success event : data: ",data
				this.emit "success",data
			else
				return new Error "File does not exist! " + res
				console.log "failed event "
				this.emit "failure","file not found"
		5000)
	print: ()->
		 console.log 'activation - print fn'

#util.inherits(activation,EventEmitter)

module.exports = new activation


