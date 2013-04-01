cloudflash
==========

CloudFlash is a web framework for cloud based automation of modules, services, and firmware

CloudFlash supports JSON data serialization format. The format for both the request and the response
should be specified by using the Content-Type header, the Accept header.

*List of APIs*
=============

<table>
  <tr>
    <th>Verb</th><th>URI</th><th>Description</th>
  </tr>
  <tr>
    <td>GET</td><td>/modules</td><td>List summary of modules installed in VCG/CPEs identified by service ID</td>
  </tr>
  <tr>
    <td>POST</td><td>/modules</td><td>Create a new module in VCG/CPE </td>
  </tr>
  <tr>
    <td>GET</td><td>/modules/module-id</td><td>Describes an installed module in VCG/CPEs by module ID</td>
  </tr>
   <tr>
    <td>PUT</td><td>/modules/module-id</td><td>Update existing module configuration in VCG/CPEs by module-id </td>
  </tr>
  <tr>
    <td>DELETE</td><td>/modules/module-id</td><td>Delete an installed module in VCG/CPEs by module ID</td>
  </tr>
  
  <tr>
    <td>POST</td><td>/modules/module-id/action</td><td>Execute command on the VCG/CPEs </td>
  </tr>

</table>


*URI structure*

For now there is no API version specified in either URI or JSON data. But, in future we plan to use
API version in the URI.

For example

      /modules/V1.0/module family/module type


*Authentication*

Current implementation of cloudflash in VCG/CPEs does not require that each request will include the credentials of
the user submiting the request.
Plan is to have OAuth scheme of authentication.

*Modules API*
==============

 List Modules
--------------

    Verb	URI	        Description
    GET	     /modules	     Lists summary of modules configured in VCG/CPEs identified by module ID.


Note: The request does not require a message body.
Success: Returns JSON data with list of modules installed on VCG/CPEs. Each module is identified by module ID

The module ID is generated is a UUID.

Module Family is the generic module type while name is the actual module name.

pkg: The package download link provided.

api: Supported APIs for this module.

*Note: Currently no validation of the package contents done*

*TODO: Caller to provide md5sum of the package along with pkgurl*


**Example Request and Response**

*Request*

    GET /modules HTTP/1.1

*Response*

```
{
       "id": "3e74a9be-9812-433a-ad26-7171612d6007",
       "description":
       {
           "name": "cloudflash-uproxy",
           "installer": "npm",
           "version": "1.0.9",
           "dependencies":
           [
               {
                   "name": "uproxy-template",
                   "version": "1.0.1",
                   "installer": "dpkg",
                   "url": "http://repository.intercloud.net/cloudflash/uproxy-template-1.0.1.deb"
               }
           ]
       },
       "status":
       {
           "installed": true,
           "initialized": false,
           "enabled": false,
           "running": false,
           "result": "Error: Command failed: "
       }
    }
```

Create Module
---------------


    Verb	URI	        Description
    POST	/modules	Create a new module in VCG/CPEs.


On success it returns JSON data with the UUID for the module created.

**Example Request and Response**

*Request*

```
{
    "name": "cloudflash-uproxy",    
    "installer":"npm",
   "version": "1.0.8",
    "dependencies":
    [
        {
             "name": "uproxy-template",
             "version": "1.0.1",
             "installer": "dpkg",
             "url": "http://repository.intercloud.net/cloudflash/uproxy-template-1.0.1.deb"
        }
    ]
}
```

*Response JSON*

```
{
               "id": "cd46985b-77f7-4094-84bd-1ad4a02210fa",
               "description":
               {
                   "name": "cloudflash-uproxy",
                   "installer": "npm",
                   "version": "1.0.8",
                   "dependencies":
                   [
                       {
                           "name": "uproxy-template",
                           "version": "1.0.1",
                           "installer": "dpkg",
                           "url": "http://repository.intercloud.net/cloudflash/uproxy-template-1.0.1.deb"
                       }
                   ]
               },
               "status":
               {
                   "installed": true
               }
           }

```

Describe Module
----------------

    Verb	URI	                 Description
    GET	    /modules/module-id	 Show a module in VCG/CPEs specified by module-ID

**Example Request and Response**

### Request Headers

    GET /modules/3e74a9be-9812-433a-ad26-7171612d600

### Response JSON

    {
       "id": "3e74a9be-9812-433a-ad26-7171612d6007",
       "description":
       {
           "name": "cloudflash-uproxy",
           "installer": "npm",
           "version": "1.0.9",
           "dependencies":
           [
               {
                   "name": "uproxy-template",
                   "version": "1.0.1",
                   "installer": "dpkg",
                   "url": "http://repository.intercloud.net/cloudflash/uproxy-template-1.0.1.deb"
               }
           ]
       },
       "status":
       {
           "installed": true,
           "initialized": false,
           "enabled": false,
           "running": false,
           "result": "Error: Command failed: "
       }
    }


Update Module
----------------

    Verb	URI	                 Description
    PUT	    /modules/module-id	 Show a module in VCG/CPEs specified by module-ID

**Example Request and Response**

*Request*
```
{
    "name": "cloudflash-uproxy",    
    "installer":"npm",
   "version": "1.0.8",
    "dependencies":
    [
        {
             "name": "uproxy-template",
             "version": "1.0.1",
             "installer": "dpkg",
             "url": "http://repository.intercloud.net/cloudflash/uproxy-template-1.0.1.deb"
        }
    ]
}
```

*Response JSON*

```
{
       "id": "95da2d83-77bf-415e-a02b-c641f59a3e84",
       "description":
       {
           "name": "cloudflash-uproxy",
           "installer": "npm",
           "version": "1.0.8",
           "dependencies":
           [
               {
                   "name": "uproxy-template",
                   "version": "1.0.1",
                   "installer": "dpkg",
                   "url": "http://repository.intercloud.net/cloudflash/uproxy-template-1.0.1.deb"
               }
           ]
       },
       "status":
       {
           "installed": true
       }
    }

```


Delete a module
----------------

    Verb	URI	                  Description
    DELETE	/modules/module-id	  Delete a module in VCG/CPEs specified by module-ID

On Success returns 200 with JSON data

*TODO: Return appropriate error code and description in case of failure.*

**Example Request and Response**

### Request Headers

    DELETE modules/2ccc8dc8-62c5-491b-b305-3c029bde6f64 

### Response JSON

    {
       "deleted": true
    }


Action Command API
------------------
This API is used to perform the action like start, stop, restart and sync on the installed modules as identified by module-id

    Verb	URI	                 Description
    POST	/modules/module-id/action	  Execute an action command

**Example Request and Response**

### Request Headers

    POST /modules/2ccc8dc8-62c5-491b-b305-3c029bde6f64/action  HTTP/1.1

### Request JSON

    {
       "command":"start"
    }

### Response JSON

    {
       "result": true
    }

