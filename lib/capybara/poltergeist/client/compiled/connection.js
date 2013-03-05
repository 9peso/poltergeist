var _this = this;

Poltergeist.Connection = (function() {

  function Connection(owner, port) {
    var _this = this;
    this.owner = owner;
    this.port = port;
    this.commandReceived = function(message) {
      return Connection.prototype.commandReceived.apply(_this, arguments);
    };
    this.socket = new WebSocket("ws://127.0.0.1:" + this.port + "/");
    this.socket.onmessage = this.commandReceived;
    this.socket.onclose = function() {
      return phantom.exit();
    };
  }

  Connection.prototype.commandReceived = function(message) {
    return this.owner.runCommand(JSON.parse(message.data));
  };

  Connection.prototype.send = function(message) {
    return this.socket.send(JSON.stringify(message));
  };

  return Connection;

})();
