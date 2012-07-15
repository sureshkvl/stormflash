cloudflash
==========

CloudFlash is a web framework for cloud based automation of openvpn, firmware, modules, and services.

CloudFlash supports JSON data serialization format. The format for both the request and the response
should be specified by using the Content-Type header, the Accept header.


*List of APIs*
=============

<table>
  <tr>
    <th>Verb</th><th>URI</th><th>Description</th>
  </tr>
  <tr>
    <td>GET</td><td>/services</td><td>List summary of services installed in VCG identified by service ID</td>
  </tr>
  <tr>
    <td>POST</td><td>/services</td><td>Create a new service in VCG</td>
  </tr>
  <tr>
    <td>DELETE</td><td>/services/service-id</td><td>Delete an installed service in VCG by service ID</td>
  </tr>
  <tr>
    <td>POST</td><td>/services/service-id/openvpn</td><td>Modify existing OpenVPN configuration</td>
  </tr>
  <tr>
    <td>POST</td><td>/services/service-id/firewall</td><td>Modify existing Firewall configuration</td>
  </tr>
  <tr>
    <td>POST</td><td>/services/service-id/action</td><td>Execute command on the VCG</td>
  </tr>
  
</table>


*URI structure*

For now there is no API version specified in either URI or JSON data. But, in future we plan to use
API version in the URI.

For example

      /services/V1.0/service family/service type


*Authentication*

Current implementation of cloudflash in VCG does not require that each request will include the credntials of
the user submiting the request.
Plan is to have OAuth scheme of authentication.

*API Description*
================

*Services*
----------

 List Services
--------------

            Verb	URI	        Description
             GET	/services	Lists summary of services configured in VCG identified by service ID.


Note: The request does not require a message body.
Success: Returns JSON data with list of services installed on VCG. Each service is identified by service ID

The service ID is generated is a UUID.

Service Family is the generic service type while name is the actual service name.

pkgurl: The package download link provided to VCG

api: Supported APIs for this service.

*Note: Currently no validation of the package contents done*

*TODO: Caller to provide md5sum of the package along with pkgurl*


**Example Request and Response**

*Request*

```
       GET /services HTTP/1.1

       Host: localhost:3000
       Connection: keep-alive
       Cache-Control: max-age=0
       User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/536.11 (KHTML, like Gecko) Chrome/20.0.1132.47 Safari/536.11
       Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
       Accept-Encoding: gzip,deflate,sdch
       Accept-Language: en-US,en;q=0.8
       Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3
```

*Response*

```
{
    "services": [
        {
            "id": "40860f06-7dcf-41ab-a414-98957b092b7b",
            "status": "installed"
            "api": "/vpnrac",
			"description": {
				 "name": "at",
            	 "family": "remote-access",
			     "version": "1.0",
            	 "pkgurl": "http://my-url.com/vpnrac-0.0.1.deb"
			}
        }
    ]
}
```

Create Service
---------------


            Verb	URI	        Description
             POST	/services	Create a new service in VCG.


The request must have the following parameters in JSON data

      1. service version
      2. service Name
      3. Service Family
      4. Package URL
      5. API path
On success it returns JSON data with the UUID for the service created.

*TODO: Define JSON format for error codes and description.*

**Example Request and Response**

### Request Headers

```
POST /services HTTP/1.1
Host: localhost:3000
Connection: keep-alive
Content-Length: 133
Origin: http://localhost:3000
X-Requested-With: XMLHttpRequest
User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/536.11 (KHTML, like Gecko) Chrome/20.0.1132.47 Safari/536.11
Content-Type: application/json; charset=UTF-8
Accept: */*
Referer: http://localhost:3000/
Accept-Encoding: gzip,deflate,sdch
Accept-Language: en-US,en;q=0.8
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3
```

### Request JSON

    {
    	"name": "at",
    	"family": "remote-access",
    	"version": "1.0",
    	"pkgurl": "http://my-url.com/vpnrac-0.0.1.deb"
    }


### Response JSON

        {
            "id": "40860f06-7dcf-41ab-a414-98957b092b7b",
            "status": "installed"
            "api": "/vpnrac",
			"description": {
				 "name": "at",
            	 "family": "remote-access",
			     "version": "1.0",
            	 "pkgurl": "http://my-url.com/vpnrac-0.0.1.deb"
			}
        }

Delete a service
----------------

            Verb	URI	                 Description
             DELETE	/services/service-id	  Delete a service in VCG specified by service-ID


On Success returns 200OK with JSON data

*TODO: Return appropriate error code and description in case of failure.*

**Example Request and Response**

### Request Headers

```
DELETE /services/d40d38bd-aab0-4430-ac61-4b8ee91dc668 HTTP/1.1
Host: localhost:3000
Connection: keep-alive
Origin: http://localhost:3000
X-Requested-With: XMLHttpRequest
User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/536.11 (KHTML, like Gecko) Chrome/20.0.1132.47 Safari/536.11
Accept: */*
Referer: http://localhost:3000/delete
Accept-Encoding: gzip,deflate,sdch
Accept-Language: en-US,en;q=0.8
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3
Response Headersview source
Connection:keep-alive
Content-Length:15
Content-Type:text/html; charset=utf-8
Date:Fri, 13 Jul 2012 22:58:34 GMT
X-Powered-By:Express
```

### Response JSON

```
{ deleted: "ok" }
```


Modify openVPN Configuration
----------------------------

            Verb	URI	        		Description
             POST	/services/service-id/openvpn	 Update the openvpn server.conf file in VCG.


The request must have the following parameters in JSON data

      1. service Name
      2. service Type
      3. Service id
      4. Openvpn config
      
On success it returns JSON data with the service-id, service Name, config success.

*TODO: Define JSON format for error codes and description.*

**Example Request and Response**

### Request Headers

```
Connection	keep-alive
Content-Length	221
Content-Type	application/json; charset=utf-8
X-Powered-By	Express
Request Headers
Accept	*/*
Accept-Encoding	gzip, deflate
Accept-Language	en-us,en;q=0.5
Cache-Control	no-cache
Connection	keep-alive
Content-Length	156
Content-Type	application/json; charset=utf-8
Host	10.2.56.153:3000
Pragma	no-cache
Referer	http://10.2.56.153:3000/
User-Agent	Mozilla/5.0 (Windows NT 5.1; rv:12.0) Gecko/20100101 Firefox/12.0
X-Requested-With	XMLHttpRequest
```

### Request JSON

     	{
     	  "services":{ 
     	               "openvpn": {
     	                            "port":7500, 
     	                            "dev": "tap test",
     	                            "proto": "udp", 
     	                            "script-security": "3 system", 
     	                            "multihome":"", 
     	                            "management": "127.0.0.1 2020",
     	                            "cipher": "AES-256-CBC", 
     	                            "tls-cipher": "AES256-SHA", 
     	                            "auth": "SHA1", 
     	                            "ca": "/etc/ca-bundle.pem",
     	                            "dh": "/etc/dh1024.pem",
     	                            "cert": "/etc/identity/snap.cert",
     	                            "key": "/etc/identity/snap.key", 
     	                            "topology": "subnet", 
     	                            "server": "10.2.55.10 255.255.255.0"
     	                            }
     	                }
     	    }

### Response JSON

        
        {
           "services":{
                        "id":"a12796b8-c786-4351-ba7d-4b95cd8e0797",
                        "name":"openvpn",
                        "config":"success"
                       }
         }
        
           



Modify the firewall Config
--------------------------


            Verb	URI	        			Description
             POST	/services/service-id/firewall		 Update the firewall firewall.sh file in VCG.


The request must have the following parameters in JSON data

      1. service Name
      2. service Type
      3. Service id
      4. firewall base64 encrypted value
      
On success it returns JSON data with the service-id, service Name, command success.

*TODO: Define JSON format for error codes and description.*

**Example Request and Response**

### Request Headers

```
Response Headersview source
Connection	keep-alive
Content-Length	95
Content-Type	application/json; charset=utf-8
X-Powered-By	Express
Request Headersview source
Accept	*/*
Accept-Encoding	gzip, deflate
Accept-Language	en-us,en;q=0.5
Cache-Control	no-cache
Connection	keep-alive
Content-Length	1107
Content-Type	application/json; charset=utf-8
Host	10.2.56.153:3000
Pragma	no-cache
Referer	http://10.2.56.153:3000/services/415794ee-c6f7-4545-a5a6-3253448de10e/firewall
User-Agent	Mozilla/5.0 (Windows NT 5.1; rv:12.0) Gecko/20100101 Firefox/12.0
X-Requested-With	XMLHttpRequest
Response Headers From Cache
Connection	keep-alive
Content-Length	95
Content-Type	application/json; charset=utf-8
X-Powered-By	Express
```

### Request JSON

            { "services":
                        { "firewall" : 
                                      { 
					"command":"IyEvYmluL3NoDQppcHRhYmxlcyAoKSB7IHRlc3QgIiQyIiAhPSAic2hvcmV3YWxsIiAmJiBzYWZlX2NhbGwgaXB0YWJsZXMgJEA7IH0NCg0Kc2FmZV9jYWxsICgpIHsNCgliaW49JCh3aGljaCAkMSkNCglzaGlmdA0KCSRiaW4gJEANCglpZiBbICQ/		ICE9IDAgXTsgdGhlbiANCgkgICAgaXB0YWJsZXMtcmVzdG9yZSA8IC9jb25maWcvaXB0YWJsZXMuc2F2ZQ0KCSAgICBleGl0IDENCglmaQ0KfQ0KIyBxdCAoKSB7ICIkQCIgPi9kZXYvbnVsbCAyPiYxIH0NCg0KaWYgWyAteCAvYmluL2J1c3lib3ggXTsgdGhlbg0KCSMgWFhYIC0gaGFjayAtIGJ1ZyB3aXRoIGlwdGFibGVzLXNhdmUgaW4gcnVudCBpbWFnZQ0KCWNwIC9ldGMvbmV0d29yay9pcHRhYmxlcy5kZWZhdWx0IC9jb25maWcvaXB0YWJsZXMuc2F2ZQ0KZWxzZQ0KCWlwdGFibGVzLXNhdmUgPiAvY29uZmlnL2lwdGFibGVzLnNhdmUNCmZpDQoNClsgLWYgL2NvbmZpZy9pcHRhYmxlcy9mdW5jdGlvbnMgXSAmJiAuIC9jb25maWcvaXB0YWJsZXMvZnVuY3Rpb25zDQoNCmlwdGFibGVzIC1MIHNob3Jld2FsbCAtbg0KaXB0YWJsZXMgLUYgc2hvcmV3YWxsDQppcHRhYmxlcyAtWCBzaG9yZXdhbGwNCmlwdGFibGVzIC10IG5hdCAtRg0KaXB0YWJsZXMgLXQgbmF0IC1YDQppcHRhYmxlcyAtdCBuYXQgLVAgUFJFUk9VVElORyBBQ0NFUFQNCmlwdGFibGVzIC10IG5hdCAtUCBQT1NUUk9VVElORyBBQ0NFUFQNCmlwdGFibGVzIC10IG5hdCAtUCBPVVRQVVQgQUNDRVBUDQppcHRhYmxlcyAtdCBtYW5nbGUgLUYNCmlwdGFibGVzIC10IG1hbmdsZSAtWA0K" 
                                      }
			}
	}


### Response JSON

        
        {
           "services":{
                        "id":"415794ee-c6f7-4545-a5a6-3253448de10e",
                        "name":"iptable",
                        "command":"success"
                       }
         }
        

Action Command API
------------------
This API is used to perform the action like start, stop, restart and status on the dinstalled services and identified by service-id

            Verb	URI	        		Description
             POST	/services/service-id/action	Execute action command .


**Example Request and Response**

### Request Headers

```
POST /services/a12796b8-c786-4351-ba7d-4b95cd8e0797/action HTTP/1.1
Host: 10.2.56.153:3000
User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:13.0) Gecko/20100101 Firefox/13.0.1
Accept: */*
Accept-Language: en-us,en;q=0.5
Accept-Encoding: gzip, deflate
Connection: keep-alive
Content-Type: application/json; charset=utf-8
X-Requested-With: XMLHttpRequest
Referer: http://10.2.56.153:3000/
Content-Length: 18
Pragma: no-cache
Cache-Control: no-cache
```

### Request JSON

         {"command":"stop"}


### Response JSON
         {
           "services":
                     {
                       "id":"a12796b8-c786-4351ba7d-4b95cd8e0797",
                        "name":"openvpn",
                        "enabled":"true",
                        "pid":9392,
                        "status":"running",
                        "action":"success"
              }
        }


