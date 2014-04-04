#argv = require('optimist')
#    .usage('Start cloudflash-bolt with a configuration file.\nUsage: $0')
#    .demand('f')
#    .default('f','/etc/bolt/bolt.json')
#    .alias('f', 'file')
#    .describe('f', 'location of bolt configuration file')
#    .argv
@include = ->
	cfgfile='/etc/bolt/bolt.json'
	config = ''
	fileops = require("fileops")
	res =  fileops.fileExistsSync cfgfile
	unless res instanceof Error
	    boltContent = fileops.readFileSync cfgfile
	    config = JSON.parse boltContent
	else
	    return new Error "file does not exist! " + res
	
	cloudflashbolt = require './boltlib'
	bolt = new cloudflashbolt config
	bolt.start (res) ->
	    if res instanceof Error
	        console.log 'error: ' + res
