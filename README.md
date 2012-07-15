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

*Delete a service*
------------------

            Verb	URI	                 Description
             DELETE	/services/service-id	  Delete a service in VCG specified by service-ID


On Success returns 200OK with JSON data

*TODO: Return appropriate error code and description in case of failure.*

Request
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

*Response*

```
{ deleted: "ok" }
```


3. Post openVPN Config API (@post /service/GUID/openvpn)
--------------------------------------------------------

4. Delete openVPN Service API (@del)
------------------------------------
	This API will delete the specific service using GUID.

5. Post Firewall Config API (@post /service/GUID/firewall)
----------------------------------------------------------

6. Delete Firewall Service API (@del)
-------------------------------------
	This API will delete the firewall service using GUID.

7. Action API (@post /service/GUID/action)
------------------------------------------
	This API will be used to perform the action like start, stop, restart and status on the
	installed services by GUID.

