argv = require('optimist')
    .usage('Start stormflash with a configuration file.\nUsage: $0')
    .demand('f')
    .default('f','/etc/stormflash/stormflash.json')
    .alias('f', 'file')
    .describe('f', 'location of stormflash configuration file')
    .argv

# config file processing logic block
config =
    port: 5000

# fileops = require("fileops")
# res =  fileops.fileExistsSync argv.file
# unless res instanceof Error
#     boltContent = fileops.readFileSync argv.file
#     config = JSON.parse boltContent
# else
#     return new Error "file does not exist! " + res


# activation logic starts here

activate = require('./lib/activation')
activate.start()

# register event into activate for when "success"
#
# 1. import stormbolt and start it
activate.on "success", (data) =>
    console.log 'received success event ',data
    stormbolt = require ('cloudflash-bolt')
    #stormbolt = require('/lib/node_modules/cloudflash-bolt/lib/bolt.coffee')
    bolt = new stormbolt data
    bolt.start (res) ->
       if res instanceof Error
            console.log 'error: ' + res

activate.on "failure", (data) =>
    console.log 'received failure event', data

# start the stormflash web application
{@app} = require('zappajs') config.port, ->
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


