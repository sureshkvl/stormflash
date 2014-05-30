(function() {
  var StormPackage;

  StormPackage = require('./stormflash').StormPackage;

  this.include = function() {
    var agent;
    agent = this.settings.agent;
    this.post({
      '/packages': function() {
        var _this = this;
        return agent.install(new StormPackage(null, this.body), function(result) {
          return _this.send(result);
        });
      }
    });
    this.get({
      '/packages': function() {
        return this.send(agent.packages.list());
      }
    });
    this.get({
      '/packages/:id': function() {
        var match;
        match = agent.packages.get(this.params.id);
        if (match !== void 0) {
          return this.send(match);
        } else {
          return this.send(404);
        }
      }
    });
    this.put({
      '/packages/:id': function() {
        return this.send(new Error("updating package currently not supported!"));
        /*
                match = agent.packages.get @params.id
                if match?
                    @send agent.upgrade match, @body
                else
                    @send 404
        */
      }
    });
    return this.del({
      '/packages/:id': function() {
        var match, result;
        match = agent.packages.get(this.params.id);
        if (match != null) {
          result = agent.remove(match);
          if (result === void 0) this.send(204);
          return this.send(500);
        } else {
          return this.send(404);
        }
      }
    });
  };

}).call(this);
