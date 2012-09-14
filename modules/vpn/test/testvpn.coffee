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
orgparams = {}
orgparams.id =  "889ace28-48e7-451a-a387-464625832891"

newservice = {"port":7000, 'dev':'tun', 'proto' : 'udp', 'ca' : 'string', 'dh':'', 'cert':'', 'key':'', 'server':''}
newuser = { "id": "889ace28-48e7-451a-a387-464625832891" ,"email": "master@oftheuniverse.com", "push": [ "dhcp-option DNS x.x.x.x","ip-win32 dynamic","route-delay 5" ]}
newsite = { "id": "889ace28-48e7-451a-a387-464625832891" ,"commonname": "server.com", "push": []}

newclientservice = {"pull": true, "tls-client":true, "dev": "tun", "proto":"udp","ca":"", "dh":"", "cert":"","key":"", "remote":"", "cipher":"", "tls-cipher":"", "route":[], "push":[], "persist-key":false}







describe 'Testing Openvpn service: ', ->

  it 'should validate json body', ->
    body = newservice
    request = orgrequest
    params = orgparams
    vpn1 = new vpn(request,body,params)
    schema = require('../src/openvpn.coffee').schema
    expect(vpn1.validateschema(schema)).to.eql({"result":"success"})

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
    vpn3 = new vpn(request, body, params)
    expect(vpn3.serviceHandler()).to.eql({"result":"success"})

  it 'should validate user and site  schema', ->
    request = body = params = null
    params = orgparams
    request = orgrequest
    request.url = "/services/#{params.id}/openvpn/users"
    request.method = 'POST'
    body = newuser
    vpn4 = new vpn(request, body, params)
    userschema = require("../src/openvpn.coffee").userschema
    expect(vpn4.validateschema(userschema)).to.eql({"result":"success"})
    body = newsite
    siteschema = require("../src/openvpn.coffee").siteschema
    expect(vpn4.validateschema(siteschema)).to.eql({"result":"success"})

  it 'should create a entry in CCD directory', ->
    body = newuser
    request = params = null
    vpn5 = new vpn(request, body, params)
    expect(vpn5.createCCDConfig("openvpn", "test@test.com")).to.eql({"result":"success"})
    exec "rm /tmp/config/openvpn/ccd/test@test.com"

  it 'should create a site in CCD directory by API call', ->
    request = body = params = null
    params = orgparams
    request = orgrequest
    request.url = "/services/#{params.id}/openvpn/sites"
    request.method = 'POST'
    body = newsite
    vpn4 = new vpn(request, body, params)
    expect(vpn4.serviceHandler()).to.eql({"result":"success"})

  it 'should create a user in CCD directory by API call', ->
    request = body = params = null
    params = orgparams
    request = orgrequest
    request.url = "/services/#{params.id}/openvpn/users"
    request.method = 'POST'
    body = newuser
    vpn4 = new vpn(request, body, params)
    expect(vpn4.serviceHandler()).to.eql({"result":"success"})
