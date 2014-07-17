Stormflash
==========

Stormflash is the core component of stormstack that realizes the intents configured in the stormlight. Stormflash can seamlessly activate, update its environment information to stormtower and thereby gets itself ready to manage the network functions in the installed environment. stormflash provides APIs that can be invoked by an external entity for managing the application lifecycle of the operating environment where stormflash is running.


*List of APIs*
----------------

<table>
  <tr>
    <th>Verb</th><th>URI</th><th>Description</th>
  </tr>
 <tr>
    <td>POST</td><td>/packages</td><td>Create a package entry</td>
  </tr> 
  <tr>
    <td>GET</td><td>/packages</td><td>Get list of packages installed identified by package ID</td>
  </tr>
  <tr>
    <td>GET</td><td>/packages/id</td><td>Get a package details by ID</td>
  </tr>
  <tr>
    <td>DELETE</td><td>/packages/id</td><td>Delete a package entry by ID</td>
  </tr> 
</table>


**POST packages API**

    Verb      URI                       Description
    POST      /packages                 Create a package entry.

On success it returns JSON data with the UUID with the packages configuration.

**Example Request and Response**

### Request JSON
   
    {
        "name": "corenova-storm",
        "version": "*",
        "source": "npm://"
    }
### Response JSON

    {
        "id": "e3db8f5c-00f3-4199-9ae2-2bf423774a17",
        "data": {
            "name": "commtouch-storm",
            "version": "*",
            "source": "npm://",
            "type": "npm",
            "status": {
                "installed": true,
                "imported": true
            },
            "id": "e3db8f5c-00f3-4199-9ae2-2bf423774a17"
        },
        "saved": true
    }


**GET packages API**

    Verb      URI                       Description
    GET       /packages                 Get list of packages installed.

On success it returns JSON data with the UUID with the packages configuration.

**Example Request and Response**

### Response JSON

    [
        {
            "name": "openvpn-storm",
            "version": "*",
            "source": "npm://",
            "type": "npm",
            "status": {
                "installed": true,
                "imported": true
            },
            "id": "5d709bbc-4f23-4ae6-9f47-f20f3f0a1add"
        },
        {
            "name": "corenova-storm",
            "version": "*",
            "source": "npm://",
            "type": "npm",
            "status": {
                "installed": true,
                "imported": true
            },
            "id": "f30571f3-7c11-4c6f-ac0b-3dcf162ccedf"
        }
    ]
    

**GET packages API**

    Verb      URI                       Description
    GET       /packages/id              Get a package details by ID.

On success it returns JSON data with the UUID with the packages configuration.

**Example Request and Response**

### Response JSON
    {
        "name": "corenova-storm",
        "version": "*",
        "source": "npm://",
        "type": "npm",
        "status": {
            "installed": true,
            "imported": true
        },
        "id": "f30571f3-7c11-4c6f-ac0b-3dcf162ccedf"
    }



**DELETE Packages API**

    Verb      URI                           Description
    DELETE   /packages/:id                  Delete existing package configuration by ID.

**Example Request and Response**

### Request Headers
DELETE /packages/:id

### Response Header

Status Code : 204 No Content




*Code Sample*
-------------------------





*Copyrights and License*
-------------------------
