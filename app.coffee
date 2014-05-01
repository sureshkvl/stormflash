argv = require('optimist')
    .usage('Start stormflash with a configuration file.\nUsage: $0')
    .demand('f')
    .default('f','/etc/stormflash/stormflash.json')
    .alias('f', 'file')
    .describe('f', 'location of stormflash configuration file')
    .argv

util=require('util')

util.log "application starts"
# config file processing logic block
fileops = require("fileops")
res = fileops.fileExistsSync argv.file
unless res instanceof Error
    stormflashContent = fileops.readFileSync argv.file
    util.log stormflashContent
#    config = JSON.parse stormflashContent
else
    util.log "stormflash config file #{argv.file} doesnot exists..."
    return new Error "file does not exist! " + res

#util.log "stormflash config contents = " + config



# activation logic starts here

activation = require('./lib/activation')
activation.start()
util.log "activation in progres...."

# register event into activate for when "success"
#
# 1. import stormbolt and start it
activation.on "success", (data) =>
    util.log 'received activattion success event with bolt config data ', data
    stormbolt = require ('stormbolt')
    bolt = new stormbolt data
    bolt.start (res) ->
       if res instanceof Error
            util.log 'bolt error: ' + res

activation.on "failure", (data) =>
    util.log 'received activation failure event with data ', data




# start the stormflash web application
{@app} = require('zappajs') 5000, ->
    @configure =>
      @use 'bodyParser', 'methodOverride', @app.router, 'static'
      @set 'basepath': '/v1.0'

    @configure
      development: => @use errorHandler: {dumpExceptions: on, showStack: on}
      production: => @use 'errorHandler'

    @enable 'serve jquery', 'minify'
    @include './lib/plugins'
    @include './lib/packages'
    @include './lib/personality'
    @include './lib/environment'


