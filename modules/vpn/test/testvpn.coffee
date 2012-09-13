# validation is used by other modules
validate = require('json-schema').validate

# To give  request input json to vpn API's. not sure this code section is correct 
# given for testing the vpn API
db = require('dirty') '/tmp/cloudflash.db'

# sample code to check db.foreach methos is not responding
db.forEach (key,val) ->
  console.log 'found ' + key
  res.services.push val
  console.log 'DB: '+res

# function to create all request 
getDBData = (id) ->
    console.log "ID: #{id}"
    entry = db.get id
    console.log 'entry: ' + entry
    if entry
        #entry.url = url
        console.log 'entry: ' + entry
        return entry
    else
        return new Error "No such service ID: #{id}"

chai = require 'chai'
expect = chai.expect
vpn = require '../src/openvpn.coffee'

# sample date to test mocha test framework
request =  getDBData "889ace28-48e7-451a-a387-464625832891"
request.url = '/services/889ace28-48e7-451a-a387-464625832891/openvpn/users'
request.method = "POST" 
params = {}
params.id =  "889ace28-48e7-451a-a387-464625832891"

switch request.url
  when "/services/#{params.id}/openvpn"
    body = {"port":7000, 'dev':'tun', 'proto' : 'udp', 'ca' : 'string', 'dh':'', 'cert':'', 'key':'', 'server':''}
    vpn1 = new vpn(request,body,params,db)
    describe 'Testing Openvpn service', ->
       it 'validate json body', ->
          expect(vpn1.validateOpenvpn()).to.eql({"result":"success"})
       it 'test the post openvpn', ->
          request = params = db = null
          expect(vpn1.serviceHandler()).to.eql({"result":"success"})

  when "/services/#{params.id}/openvpn/users"
    body = { "id": "889ace28-48e7-451a-a387-464625832891" ,"email": "master@oftheuniverse.com", "push": [ "dhcp-option DNS x.x.x.x","ip-win32 dynamic","route-delay 5" ]}
    vpn1 = new vpn(request,body,params,db)
    describe 'Testing Openvpn user service', ->
       it 'validate json body', ->
          expect(vpn1.validateOpenvpnUser()).to.eql({"result":"success"})
       it 'test the post openvpn', ->
          request = params = db = null
          expect(vpn1.serviceHandler()).to.eql({"result":"success"})

  when "/services/#{params.id}/openvpn/sites"
    body = { "id": "889ace28-48e7-451a-a387-464625832891" ,"commonname": "mastertest@oftheuniverse.com", "push": [ "dhcp-option DNS x.x.x.x","ip-win32 dynamic","route-delay 5" ]}
    vpn1 = new vpn(request,body,params,db)
    describe 'Testing Openvpn user service', ->
       it 'validate json body', ->
          expect(vpn1.validateOpenvpnSite()).to.eql({"result":"success"})
       it 'test the post openvpn', ->
          request = params = db = null
          expect(vpn1.serviceHandler()).to.eql({"result":"success"})

  else
    body = null
    validateFunction = null
  

