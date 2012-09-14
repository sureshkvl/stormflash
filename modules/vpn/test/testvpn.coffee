chai = require 'chai'
expect = chai.expect
vpn = require '../src/openvpn.coffee'
exec = require('child_process').exec

# sample date to test mocha test framework
http = require('http')

options = {port:80, host:'google.com'}
orgrequest = http.request(options)
orgrequest.url = '/services/889ace28-48e7-451a-a387-464625832891/openvpn'
orgrequest.method = "POST" 
# Added to sync testing from RESTclient and mocha framework  to add file CCD dir
orgrequest.service = {}
orgrequest.service.description ={}
orgrequest.service.description.name = "openvpn"

orgparams = {}
orgparams.id =  "889ace28-48e7-451a-a387-464625832891"


newservice = {"port":7000, 'dev':'tun', 'proto' : 'udp', 'ca' : 'string', 'dh':'', 'cert':'', 'key':'', 'server':''}
newuser = { "id": "889ace28-48e7-451a-a387-464625832891" ,"email": "master@oftheuniverse.com", "push": [ "dhcp-option DNS x.x.x.x","ip-win32 dynamic","route-delay 5" ]}
newsite = { "id": "889ace28-48e7-451a-a387-464625832891" ,"commonname": "server.com", "push": []}
newclientservice = {"pull": true, "tls-client":true, "dev": "tun", "proto":"udp","ca":"", "dh":"", "cert":"","key":"", "remote":"", "cipher":"", "tls-cipher":"", "route":[], "push":[], "persist-key":false}

# invalid inputs for testing
newservice_err = {"port":"7000", 'dev':'tun', 'proto' : 'udp', 'ca' : 'string', 'dh':'', 'cert':'', 'key':'', 'server':''}
newuser_err  = { "id": "889ace28-48e7-451a-a387-464625832891" ,"emailtest": "master@oftheuniverse.com", "push": [ "dhcp-option DNS x.x.x.x","ip-win32 dynamic","route-delay 5" ]}
newsite_err  = { "id": "889ace28-48e7-451a-a387-464625832891" ,"commonnametest": "server.com", "push": []}
newclientservice_err  = {"pull": "true", "tls-client":true, "dev": "tun", "proto":"udp","ca":"", "dh":"", "cert":"","key":"", "remote":"", "cipher":"", "tls-cipher":"", "route":[], "push":[], "persist-key":false}



describe 'Testing Openvpn service: ', ->

  it 'should validate json body', ->
    body = newservice
    request = orgrequest
    params = orgparams
    vpn1 = new vpn(request,body,params)
    #schema = require('../src/openvpn.coffee').schema
    expect(vpn1.validateschema(vpn1.serverschema)).to.eql({"result":"success"})

  it 'should create configuration', ->
    request = params = db = null
    filename = 'server.conf'
    request = orgrequest
    body = newservice
    params = orgparams
    vpn2 = new vpn(request,body,params)
    res = vpn2.createOpenvpnConfig(filename)
    console.log res
    expect(res).to.eql({"result":"success"})

  it 'should create config based on request path POST /services/:id/openvpn', ->
    request = body = db = null
    params = orgparams
    request = orgrequest
    request.url = "/services/#{params.id}/openvpn"
    request.method = 'POST'
    body = newservice
    vpn3 = new vpn(request, body, params)
    expect(vpn3.serviceHandler()).to.eql({"result":"success"})
  
  it 'should create config based on request path POST /services/:id/openvpn/client', ->
    request = body = db = null
    params = orgparams
    request = orgrequest
    request.url = "/services/#{params.id}/openvpn/client"
    request.method = 'POST'
    body = newclientservice
    vpn4 = new vpn(request, body, params)
    expect(vpn4.serviceHandler()).to.eql({"result":"success"})

  it 'should validate user and site  schema', ->
    request = body = params = null
    params = orgparams
    request = orgrequest
    request.url = "/services/#{params.id}/openvpn/users"
    request.method = 'POST'
    body = newuser
    vpn5 = new vpn(request, body, params)
    #userschema = require("../src/openvpn.coffee").userschema
    expect(vpn5.validateschema(vpn5.userschema)).to.eql({"result":"success"})
    body = newsite
    vpn51 = new vpn(request, body, params)
    siteschema = require("../src/openvpn.coffee").siteschema
    expect(vpn51.validateschema(vpn51.siteschema)).to.eql({"result":"success"})

  it 'should create a entry in CCD directory', ->
    body = newuser
    request = params = null
    vpn6 = new vpn(request, body, params)
    expect(vpn6.createCCDConfig("openvpn", "test@test.com")).to.eql({"result":"success"})
    exec "rm /tmp/config/openvpn/ccd/test@test.com"

  it 'should create a site in CCD directory by API call', ->
    request = body = params = null
    params = orgparams
    request = orgrequest    
    request.url = "/services/#{params.id}/openvpn/sites"
    request.method = 'POST'
    body = newsite
    vpn7 = new vpn(request, body, params)
    expect(vpn7.serviceHandler()).to.eql({"result":"success"})

  it 'should create a user in CCD directory by API call', ->
    request = body = params = null
    params = orgparams
    request = orgrequest
    request.url = "/services/#{params.id}/openvpn/users"
    request.method = 'POST'
    body = newuser
    vpn8 = new vpn(request, body, params)
    expect(vpn8.serviceHandler()).to.eql({"result":"success"})
  
  #error test cases
  #Test with validateschema for invalid schema for openvpn
  it 'should not validate json body with error invalid schema', ->
    request = body = params = null
    body = newservice_err
    request = orgrequest
    params = orgparams
    vpn9 = new vpn(request,body,params)
    expect(vpn9.validateschema(vpn9.serverschema)).to.not.equal({"result":"success"})

  #Test with body as null for openvpn  //  test result fails
  it 'should not validate json body with error body null', ->
    request = body = params = null
    body = null
    request = orgrequest
    params = orgparams
    vpn10 = new vpn(request,body,params)
    expect(vpn10.validateschema(vpn10.serverschema)).to.not.equal({"result":"success"})

  #Test with filename as null for openvpn createOpenvpnConfig  
  it 'should not create configuration with error filename null', ->
    request = params = db = null
    filename = ''
    request = orgrequest
    body = newservice
    params = orgparams
    vpn11 = new vpn(request,body,params)
    res = vpn11.createOpenvpnConfig(filename)
    console.log res
    expect(res).to.not.equal({"result":"success"})

  #Test with serviceHandler with params as null   //  test result fails 
  it 'should not create config based on request path POST /services/:id/openvpn with error inputs params as null', ->
    request = body = params = null
    params = ''
    request = orgrequest
    request.url = "/services/#{params.id}/openvpn"
    request.method = 'POST'
    body = newservice
    vpn12 = new vpn(request, body, params)
    expect(vpn12.serviceHandler()).to.not.equal({"result":"success"})

  #Test with serviceHandler with invalid request 
  it 'should not create config based on request path POST /services/:id/openvpn with error inputs invalid request method', ->
    request = body = params = null
    params = ''
    request = orgrequest
    request.url = "/servicestest/#{params.id}/openvpn"
    request.method = 'POST'
    body = newservice
    vpn13 = new vpn(request, body, params)
    expect(vpn13.serviceHandler()).to.not.equal({"result":"success"})

  #Test with validateschema for invalid schema for user and site  
  it 'should not validate user and site  schema', ->
    request = body = params = null
    params = orgparams
    request = orgrequest
    body = newuser_err
    vpn14 = new vpn(request, body, params)
    expect(vpn14.validateschema(vpn14.userschema)).to.not.equal({"result":"success"})
    body = newsite_err
    vpn15 = new vpn(request, body, params)
    expect(vpn15.validateschema(vpn15.siteschema)).to.not.equal({"result":"success"})

  #Test with validateschema for invalid schema for openvpn client
  it 'should not validate json body with error invalid schema for client', ->
    request = body = params = null
    body = newclientservice_err
    request = orgrequest
    params = orgparams
    vpn16 = new vpn(request,body,params)
    expect(vpn16.validateschema(vpn16.clientschema)).to.not.equal({"result":"success"})


 #Test DELETE user
 #Test DELETE site
 #Test with wrong values for DELETE user
 #Test with wrong vlaues for DELETE site
 



