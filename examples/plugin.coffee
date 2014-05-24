sf = require('../src/stormflash').StormFlash
agent = new sf()
StormPackage = require('../src/stormflash').StormPackage

packages = [
    #            "name": "test",
    #            "version" : "0.0.1",
    #            "source" : "npm://testnpm",
    #          ,
    #            "name": "debtest",
    #            "version" : "0.2.2",
    #            "source" : "dpkg://testme.com/testdeb.pkg",
    #          ,
            "name": "cloudflash-openvpn",
            "version" : "*",
            "source" : "npm://",
      ]
    
       
getListofpackages = ->
    console.log "RAVIRAVIRAVIRAVIRAVIRAVIRAVIRAVI"
    console.log agent.packages.list()


getSpecificPackage = ->
    console.log agent.packages.get "db597ddd-758a-4314-817e-5006ea99b1ed"


deletePackage = ->
    console.log agent.packages.remove "db597ddd-758a-4314-817e-5006ea99b1ed"

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

    console.log agent.instances.add "server", instance
    agent.start "server", (result) ->
        console.log result

#setTimeout getListofPackages, 500
setTimeout ()->
    createInstance()
#    testPackageInstall()
#    getSpecificPackage()
#    getListofpackages()
#    deletePackage()
, 1000
