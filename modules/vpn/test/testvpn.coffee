chai = require 'chai'
expect = chai.expect
vpn = require '../src/openvpn.coffee'

vpn1 = new vpn
body = {"port":7000, 'dev':'tun', 'proto' : 'udp', 'ca' : 'string', 'dh':'', 'cert':'', 'key':'', 'server':''}
describe 'Testing Openvpn service', ->
  it 'validate json body', ->
    expect(vpn1.validateOpenvpn()).to.eql({"result":"success"})
  it 'test sample function', ->
    expect(vpn1.sample()).to.eql("true")
  it 'test the post openvpn', ->
    request = params = db = null
    expect(vpn1.serviceHandler()).to.eql({"result":"success"})

