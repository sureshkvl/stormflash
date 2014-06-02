sf = require('../src/stormflash').StormFlash
require('look').start()

agent = new sf()
StormPackage = require('../src/stormflash').StormPackage
StormInstance = require('../src/stormflash').StormInstance

packages = [
    #            "name": "test",
    #            "version" : "0.0.1",
    #            "source" : "npm://testnpm",
    #          ,
    #            "name": "debtest",
    #            "version" : "0.2.2",
    #            "source" : "dpkg://testme.com/testdeb.pkg",
    #          ,
            "name": "stormkeeper",
            "version" : "*",
            "source" : "npm://",
      ]
    
       
getListofpackages = ->
    console.log "List of Packages .........................................................."
    agent.packages.list()


getSpecificPackage = ->
    console.log agent.packages.get "mypkg"


deletePackage = ->
    console.log agent.packages.remove "mypkg"


testPackageInstall = ->
    for pkg in packages
        agent.install pkg , (result) ->
            if result instanceof Error
                console.log "Failed. Reason is ", result
             console.log "Success in installing the package" unless result instanceof Error


createInstance = ->
    instance =
            name: "server"
            path: "/home/rchunduru/workspace/coffee"
            monitor: true

    sinstance = new StormInstance "testserver", instance
    res = agent.instances.add "testserver", sinstance
    console.log "result to add instance", res
    agent.instances.get "testserver", (instance) =>
        console.log "response to get ", instance
        return  if instance instanceof Error

    console.log agent.instances.list()
    agent.start "testserver", (result, error) =>
        console.log "result of starting procesS", result, error
        agent.stop "testserver", (result) =>

getInstances = ->
    console.log "Get List of Instances.................................."
    console.log agent.instances.list()


discoverInstances = ->
    agent.instances.discover()

#setTimeout getListofPackages, 500
#agent.spm.monitorNpmModules()
#
#
console.log "Matching zappajs with packages.............................."
setTimeout ()->
    #agent.spm.monitorDebPkgs()
    #agent.spm.monitor 8000
    #agent.instances.discover()
    #discoverInstances()
    #getInstances()
    #createInstance()
    testPackageInstall()
#    getSpecificPackage()
    ()->
    #    getListofpackages()
#    deletePackage()
, 100


setTimeout () ->
    agent.packages.find "zappajs", "*"
, 2000
