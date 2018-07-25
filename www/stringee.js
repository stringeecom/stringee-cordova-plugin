/*global cordova, module*/

// TODO: Global variables

var StringeePlugin,
  StringeeError,
  StringeeSuccess,
  StringeeGenerateIdentifier,
  StringeeGetZIndex,
  StringeeGenerateDomHelper,
  getPosition;

StringeePlugin = "StringeePlugin";

StringeeError = function(error) {
  return console.log("Error: ", error);
};

StringeeSuccess = function() {
  return console.log("success");
};

StringeeGenerateIdentifier = function() {
  var identifier = "Stringee" + Date.now();
  return identifier;
};

StringeeGetZIndex = function(ele) {
  var val;
  while (ele != null) {
    val = document.defaultView
      .getComputedStyle(ele, null)
      .getPropertyValue("z-index");
    if (parseInt(val)) {
      return val;
    }
    ele = ele.offsetParent;
  }
  return 0;
};

StringeeGenerateDomHelper = function() {
  var div, domId;
  domId = "StringeeVideo" + Date.now();
  div = document.createElement("div");
  div.setAttribute("id", domId);
  document.body.appendChild(div);
  return domId;
};

getPosition = function(pubDiv) {
  var computedStyle, curleft, curtop, height, width;
  if (!pubDiv) {
    return {};
  }
  computedStyle = window.getComputedStyle ? getComputedStyle(pubDiv, null) : {};
  width = pubDiv.offsetWidth;
  height = pubDiv.offsetHeight;
  curtop = pubDiv.offsetTop;
  curleft = pubDiv.offsetLeft;
  while ((pubDiv = pubDiv.offsetParent)) {
    curleft += pubDiv.offsetLeft;
    curtop += pubDiv.offsetTop;
  }
  return {
    top: curtop,
    left: curleft,
    width: width,
    height: height
  };
};

// TODO: Khai báo lớp trung mà bên ngoài sẽ gọi Plugin

window.Stringee = {
  initStringeeClient: function() {
    return new StringeeClient();
  },
  initStringeeCall: function(
    from,
    to,
    isVideoCall,
    videoResolution,
    customData
  ) {
    return new StringeeCall(
      true,
      from,
      to,
      isVideoCall,
      videoResolution,
      customData
    );
  },
  showLog: function(a) {
    return console.log(a);
  },
  getHelper: function() {
    if (typeof jasmine === "undefined" || !jasmine || !jasmine["getEnv"]) {
      window.jasmine = {
        getEnv: function() {}
      };
    }
    this.StringeeHelper = this.StringeeHelper || StringeeHelpers.noConflict();
    return this.StringeeHelper;
  },
  requestPermissions: function(camera, successCallback, errorCallback) {
    Cordova.exec(
      successCallback,
      errorCallback,
      StringeePlugin,
      "requestPermissions",
      [camera]
    );
  }
};

// TODO: Tạo lớp StringeeClient

var StringeeClient,
  __bind = function(fn, me) {
    return function() {
      return fn.apply(me, arguments);
    };
  };

StringeeClient = (function() {
  // Hàm khởi tạo
  function StringeeClient() {
    // Properties
    this.userId = null;
    this.hasConnected = false;

    this.didConnect = __bind(this.didConnect, this);
    this.didDisConnect = __bind(this.didDisConnect, this);
    this.didFailWithError = __bind(this.didFailWithError, this);
    this.requestAccessToken = __bind(this.requestAccessToken, this);
    this.incomingCall = __bind(this.incomingCall, this);

    this.eventReceived = __bind(this.eventReceived, this);
    Stringee.getHelper().eventing(this);
    Cordova.exec(
      StringeeSuccess,
      StringeeError,
      StringeePlugin,
      "initStringeeClient",
      []
    );
  }

  // Functions
  StringeeClient.prototype.connect = function(token) {
    this.token = token;
    if (token == "" || token == null) {
      Stringee.showLog("Can not connect to Stringee server. Token is invalid");
      return;
    }

    Cordova.exec(
      this.eventReceived,
      StringeeError,
      StringeePlugin,
      "addEvent",
      ["clientEvents"]
    );
    Cordova.exec(StringeeSuccess, StringeeError, StringeePlugin, "connect", [
      this.token
    ]);
  };

  StringeeClient.prototype.disconnect = function() {
    Cordova.exec(
      StringeeSuccess,
      StringeeError,
      StringeePlugin,
      "disconnect",
      []
    );
  };

  StringeeClient.prototype.registerPush = function(
    deviceToken,
    isProduction,
    isVoip,
    successCallback,
    errorCallback
  ) {
    Cordova.exec(
      successCallback,
      errorCallback,
      StringeePlugin,
      "registerPush",
      [deviceToken, isProduction, isVoip]
    );
  };

  StringeeClient.prototype.unregisterPush = function(
    deviceToken,
    successCallback,
    errorCallback
  ) {
    Cordova.exec(
      successCallback,
      errorCallback,
      StringeePlugin,
      "unregisterPush",
      [deviceToken]
    );
  };

  // Events
  StringeeClient.prototype.eventReceived = function(response) {
    return this[response.eventType](response.data);
  };

  StringeeClient.prototype.didConnect = function(event) {
    this.userId = event.userId;
    this.hasConnected = true;

    var connectionEvent = new StringeeEvent("didConnect");
    connectionEvent.userId = event.userId;
    connectionEvent.projectId = event.projectId;
    connectionEvent.isReconnecting = event.isReconnecting;
    this.dispatchEvent(connectionEvent);
    return this;
  };

  StringeeClient.prototype.didDisConnect = function(event) {
    this.hasConnected = false;

    var connectionEvent = new StringeeEvent("didDisConnect");
    connectionEvent.userId = event.userId;
    connectionEvent.projectId = event.projectId;
    connectionEvent.isReconnecting = event.isReconnecting;
    this.dispatchEvent(connectionEvent);
    return this;
  };

  StringeeClient.prototype.didFailWithError = function(event) {
    this.hasConnected = false;

    var connectionEvent = new StringeeEvent("didFailWithError");
    connectionEvent.userId = event.userId;
    connectionEvent.code = event.code;
    connectionEvent.message = event.message;
    this.dispatchEvent(connectionEvent);
    return this;
  };

  StringeeClient.prototype.requestAccessToken = function(event) {
    this.hasConnected = false;

    var connectionEvent = new StringeeEvent("requestAccessToken");
    connectionEvent.userId = event.userId;
    this.dispatchEvent(connectionEvent);
    return this;
  };

  StringeeClient.prototype.incomingCall = function(event) {
    var connectionEvent = new StringeeEvent("incomingCall");
    var incCall = new StringeeCall(false, "", "", false, "", "");
    incCall.identifier = event.callId;
    incCall.callId = event.callId;
    incCall.from = event.from;
    incCall.to = event.to;
    incCall.fromAlias = event.fromAlias;
    incCall.toAlias = event.toAlias;
    incCall.callType = event.callType;
    incCall.customDataFromYourServer = event.customDataFromYourServer;
    connectionEvent.call = incCall;

    this.dispatchEvent(connectionEvent);
    return this;
  };

  return StringeeClient;
})();

// TODO: Tạo lớp StringeeCall

var StringeeCall,
  __bind = function(fn, me) {
    return function() {
      return fn.apply(me, arguments);
    };
  };

StringeeCall = (function() {
  // Hàm khởi tạo
  function StringeeCall(
    isOutgoingCall,
    from,
    to,
    isVideoCall,
    videoResolution,
    customData
  ) {
    this.identifier = StringeeGenerateIdentifier();

    // Properties
    this.callId = null;
    this.from = null;
    this.to = null;
    this.fromAlias = null;
    this.toAlias = null;
    this.callType = null;
    this.customDataFromYourServer = null;

    this.didChangeSignalingState = __bind(this.didChangeSignalingState, this);
    this.didChangeMediaState = __bind(this.didChangeMediaState, this);
    this.didReceiveLocalStream = __bind(this.didReceiveLocalStream, this);
    this.didReceiveRemoteStream = __bind(this.didReceiveRemoteStream, this);
    this.didReceiveDtmfDigit = __bind(this.didReceiveDtmfDigit, this);
    this.didReceiveCallInfo = __bind(this.didReceiveCallInfo, this);
    this.didHandleOnAnotherDevice = __bind(this.didHandleOnAnotherDevice, this);

    this.eventReceived = __bind(this.eventReceived, this);
    Stringee.getHelper().eventing(this);

    if (isOutgoingCall) {
      // Là cuộc gọi đi thì mới tạo trong native
      Cordova.exec(
        StringeeSuccess,
        StringeeError,
        StringeePlugin,
        "initStringeeCall",
        [this.identifier, from, to, isVideoCall, videoResolution, customData]
      );
    }
  }

  // Functions
  StringeeCall.prototype.makeCall = function(successCallback, errorCallback) {
    Cordova.exec(
      this.eventReceived,
      StringeeError,
      StringeePlugin,
      "addEvent",
      [this.identifier]
    );

    var weakself = this;
    var handleSuccessCallback = function(event) {
      weakself.callId = event.callId;
      weakself.from = event.from;
      weakself.to = event.to;
      weakself.fromAlias = event.fromAlias;
      weakself.toAlias = event.toAlias;
      weakself.callType = event.callType;
      weakself.customDataFromYourServer = event.customDataFromYourServer;
      successCallback(event);
    };

    Cordova.exec(
      handleSuccessCallback,
      errorCallback,
      StringeePlugin,
      "makeCall",
      [this.identifier]
    );
  };

  StringeeCall.prototype.initAnswer = function(successCallback, errorCallback) {
    Cordova.exec(
      this.eventReceived,
      StringeeError,
      StringeePlugin,
      "addEvent",
      [this.identifier]
    );
    Cordova.exec(successCallback, errorCallback, StringeePlugin, "initAnswer", [
      this.identifier
    ]);
  };

  StringeeCall.prototype.answer = function(successCallback, errorCallback) {
    Cordova.exec(successCallback, errorCallback, StringeePlugin, "answer", [
      this.identifier
    ]);
  };

  StringeeCall.prototype.hangup = function(successCallback, errorCallback) {
    Cordova.exec(successCallback, errorCallback, StringeePlugin, "hangup", [
      this.identifier
    ]);
  };

  StringeeCall.prototype.reject = function(successCallback, errorCallback) {
    Cordova.exec(successCallback, errorCallback, StringeePlugin, "reject", [
      this.identifier
    ]);
  };

  StringeeCall.prototype.sendDTMF = function(
    dtmf,
    successCallback,
    errorCallback
  ) {
    Cordova.exec(successCallback, errorCallback, StringeePlugin, "sendDTMF", [
      this.identifier,
      dtmf
    ]);
  };

  StringeeCall.prototype.sendCallInfo = function(
    info,
    successCallback,
    errorCallback
  ) {
    Cordova.exec(
      successCallback,
      errorCallback,
      StringeePlugin,
      "sendCallInfo",
      [this.identifier, info]
    );
  };

  StringeeCall.prototype.getCallStats = function(
    successCallback,
    errorCallback
  ) {
    Cordova.exec(
      successCallback,
      errorCallback,
      StringeePlugin,
      "getCallStats",
      [this.identifier]
    );
  };

  StringeeCall.prototype.mute = function(mute, successCallback, errorCallback) {
    Cordova.exec(successCallback, errorCallback, StringeePlugin, "mute", [
      this.identifier,
      mute
    ]);
  };

  StringeeCall.prototype.setSpeakerphoneOn = function(
    speaker,
    successCallback,
    errorCallback
  ) {
    Cordova.exec(
      successCallback,
      errorCallback,
      StringeePlugin,
      "setSpeakerphoneOn",
      [this.identifier, speaker]
    );
  };

  StringeeCall.prototype.switchCamera = function(
    successCallback,
    errorCallback
  ) {
    Cordova.exec(
      successCallback,
      errorCallback,
      StringeePlugin,
      "switchCamera",
      [this.identifier]
    );
  };

  StringeeCall.prototype.enableVideo = function(
    enable,
    successCallback,
    errorCallback
  ) {
    Cordova.exec(
      successCallback,
      errorCallback,
      StringeePlugin,
      "enableVideo",
      [this.identifier, enable]
    );
  };

  StringeeCall.prototype.renderVideo = function(
    isLocal,
    element,
    successCallback,
    errorCallback
  ) {
    var targetElement = document.getElementById(element);
    var position = getPosition(targetElement);
    var zIndex = StringeeGetZIndex(targetElement);

    Cordova.exec(
      successCallback,
      errorCallback,
      StringeePlugin,
      "renderVideo",
      [
        this.identifier,
        isLocal,
        position.top,
        position.left,
        position.width,
        position.height,
        zIndex
      ]
    );
  };

  // Events
  StringeeCall.prototype.eventReceived = function(response) {
    return this[response.eventType](response.data);
  };

  StringeeCall.prototype.didChangeSignalingState = function(event) {
    var connectionEvent = new StringeeEvent("didChangeSignalingState");
    connectionEvent.callId = event.callId;
    connectionEvent.code = event.code;
    connectionEvent.reason = event.reason;
    connectionEvent.sipCode = event.sipCode;
    connectionEvent.sipReason = event.sipReason;
    this.dispatchEvent(connectionEvent);
    return this;
  };

  StringeeCall.prototype.didChangeMediaState = function(event) {
    var connectionEvent = new StringeeEvent("didChangeMediaState");
    connectionEvent.callId = event.callId;
    connectionEvent.code = event.code;
    connectionEvent.description = event.description;
    this.dispatchEvent(connectionEvent);
    return this;
  };

  StringeeCall.prototype.didReceiveLocalStream = function(event) {
    var connectionEvent = new StringeeEvent("didReceiveLocalStream");
    connectionEvent.callId = event.callId;
    this.dispatchEvent(connectionEvent);
    return this;
  };

  StringeeCall.prototype.didReceiveRemoteStream = function(event) {
    var connectionEvent = new StringeeEvent("didReceiveRemoteStream");
    connectionEvent.callId = event.callId;
    this.dispatchEvent(connectionEvent);
    return this;
  };

  StringeeCall.prototype.didReceiveDtmfDigit = function(event) {
    var connectionEvent = new StringeeEvent("didReceiveDtmfDigit");
    connectionEvent.callId = event.callId;
    connectionEvent.dtmf = event.dtmf;
    this.dispatchEvent(connectionEvent);
    return this;
  };

  StringeeCall.prototype.didReceiveCallInfo = function(event) {
    var connectionEvent = new StringeeEvent("didReceiveCallInfo");
    connectionEvent.callId = event.callId;
    connectionEvent.data = event.data;
    this.dispatchEvent(connectionEvent);
    return this;
  };

  StringeeCall.prototype.didHandleOnAnotherDevice = function(event) {
    var connectionEvent = new StringeeEvent("didHandleOnAnotherDevice");
    connectionEvent.callId = event.callId;
    connectionEvent.code = event.code;
    connectionEvent.description = event.description;
    this.dispatchEvent(connectionEvent);
    return this;
  };

  return StringeeCall;
})();

// TODO: Tạo lớp StringeeEvent

var StringeeEvent,
  __bind = function(fn, me) {
    return function() {
      return fn.apply(me, arguments);
    };
  };

StringeeEvent = (function() {
  function StringeeEvent(type, cancelable) {
    this.preventDefault = __bind(this.preventDefault, this);
    this.isDefaultPrevented = __bind(this.isDefaultPrevented, this);
    this.type = type;
    this.cancelable = cancelable !== void 0 ? cancelable : true;
    this._defaultPrevented = false;
    return;
  }

  StringeeEvent.prototype.isDefaultPrevented = function() {
    return this._defaultPrevented;
  };

  StringeeEvent.prototype.preventDefault = function() {
    if (this.cancelable) {
      this._defaultPrevented = true;
    } else {
      console.log(
        "Event.preventDefault: Trying to prevent default on an Event that isn't cancelable"
      );
    }
  };

  return StringeeEvent;
})();

// TODO: Tạo StringeeHelpers

!(function(window, undefined) {
  var StringeeHelpers = function(domId) {
    return document.getElementById(domId);
  };

  var previousStringeeHelpers = window.StringeeHelpers;

  window.StringeeHelpers = StringeeHelpers;

  StringeeHelpers.keys =
    Object.keys ||
    function(object) {
      var keys = [],
        hasOwnProperty = Object.prototype.hasOwnProperty;
      for (var key in object) {
        if (hasOwnProperty.call(object, key)) {
          keys.push(key);
        }
      }
      return keys;
    };

  var _each =
    Array.prototype.forEach ||
    function(iter, ctx) {
      for (var idx = 0, count = this.length || 0; idx < count; ++idx) {
        if (idx in this) {
          iter.call(ctx, this[idx], idx);
        }
      }
    };

  StringeeHelpers.forEach = function(array, iter, ctx) {
    return _each.call(array, iter, ctx);
  };

  var _map =
    Array.prototype.map ||
    function(iter, ctx) {
      var collect = [];
      _each.call(this, function(item, idx) {
        collect.push(iter.call(ctx, item, idx));
      });
      return collect;
    };

  StringeeHelpers.map = function(array, iter) {
    return _map.call(array, iter);
  };

  var _filter =
    Array.prototype.filter ||
    function(iter, ctx) {
      var collect = [];
      _each.call(this, function(item, idx) {
        if (iter.call(ctx, item, idx)) {
          collect.push(item);
        }
      });
      return collect;
    };

  StringeeHelpers.filter = function(array, iter, ctx) {
    return _filter.call(array, iter, ctx);
  };

  var _some =
    Array.prototype.some ||
    function(iter, ctx) {
      var any = false;
      for (var idx = 0, count = this.length || 0; idx < count; ++idx) {
        if (idx in this) {
          if (iter.call(ctx, this[idx], idx)) {
            any = true;
            break;
          }
        }
      }
      return any;
    };

  StringeeHelpers.some = function(array, iter, ctx) {
    return _some.call(array, iter, ctx);
  };

  var _indexOf =
    Array.prototype.indexOf ||
    function(searchElement, fromIndex) {
      var i,
        pivot = fromIndex ? fromIndex : 0,
        length;

      if (!this) {
        throw new TypeError();
      }

      length = this.length;

      if (length === 0 || pivot >= length) {
        return -1;
      }

      if (pivot < 0) {
        pivot = length - Math.abs(pivot);
      }

      for (i = pivot; i < length; i++) {
        if (this[i] === searchElement) {
          return i;
        }
      }
      return -1;
    };

  StringeeHelpers.arrayIndexOf = function(array, searchElement, fromIndex) {
    return _indexOf.call(array, searchElement, fromIndex);
  };

  var _bind =
    Function.prototype.bind ||
    function() {
      var args = Array.prototype.slice.call(arguments),
        ctx = args.shift(),
        fn = this;
      return function() {
        return fn.apply(
          ctx,
          args.concat(Array.prototype.slice.call(arguments))
        );
      };
    };

  StringeeHelpers.bind = function() {
    var args = Array.prototype.slice.call(arguments),
      fn = args.shift();
    return _bind.apply(fn, args);
  };

  var _trim =
    String.prototype.trim ||
    function() {
      return this.replace(/^\s+|\s+$/g, "");
    };

  StringeeHelpers.trim = function(str) {
    return _trim.call(str);
  };

  StringeeHelpers.noConflict = function() {
    StringeeHelpers.noConflict = function() {
      return StringeeHelpers;
    };
    window.StringeeHelpers = previousStringeeHelpers;
    return StringeeHelpers;
  };

  StringeeHelpers.isNone = function(obj) {
    return obj === undefined || obj === null;
  };

  StringeeHelpers.isObject = function(obj) {
    return obj === Object(obj);
  };

  StringeeHelpers.isFunction = function(obj) {
    return (
      !!obj &&
      (obj.toString().indexOf("()") !== -1 ||
        Object.prototype.toString.call(obj) === "[object Function]")
    );
  };
})(window);

(function(window, StringeeHelpers, undefined) {
  StringeeHelpers.eventing = function(self, syncronous) {
    var _events = {};

    // Call the defaultAction, passing args
    function executeDefaultAction(defaultAction, args) {
      if (!defaultAction) return;

      defaultAction.apply(null, args.slice());
    }

    function executeListenersSyncronously(name, args) {
      // defaultAction is not used
      var listeners = _events[name];
      if (!listeners || listeners.length === 0) return;

      StringeeHelpers.forEach(listeners, function(listener) {
        // index
        (listener.closure || listener.handler).apply(
          listener.context || null,
          args
        );
      });
    }

    var executeListeners =
      syncronous === true
        ? executeListenersSyncronously
        : executeListenersSyncronously;

    var removeAllListenersNamed = function(eventName, context) {
      if (_events[eventName]) {
        if (context) {
          // We are removing by context, get only events that don't
          // match that context
          _events[eventName] = StringeeHelpers.filter(
            _events[eventName],
            function(listener) {
              return listener.context !== context;
            }
          );
        } else {
          delete _events[eventName];
        }
      }
    };

    var addListeners = StringeeHelpers.bind(function(
      eventNames,
      handler,
      context,
      closure
    ) {
      var listener = { handler: handler };
      if (context) listener.context = context;
      if (closure) listener.closure = closure;

      StringeeHelpers.forEach(eventNames, function(name) {
        if (!_events[name]) _events[name] = [];
        _events[name].push(listener);
      });
    },
    self);

    var removeListeners = function(eventNames, handler, context) {
      function filterHandlerAndContext(listener) {
        return !(listener.handler === handler && listener.context === context);
      }

      StringeeHelpers.forEach(
        eventNames,
        StringeeHelpers.bind(function(name) {
          if (_events[name]) {
            _events[name] = StringeeHelpers.filter(
              _events[name],
              filterHandlerAndContext
            );
            if (_events[name].length === 0) delete _events[name];
          }
        }, self)
      );
    };

    self.dispatchEvent = function(event, defaultAction) {
      if (!event.type) {
        String.showLog("DispatchEvent error: Event has no type");
        throw new Error("DispatchEvent error: Event has no type");
      }

      if (!event.target) {
        event.target = this;
      }

      if (!_events[event.type] || _events[event.type].length === 0) {
        executeDefaultAction(defaultAction, [event]);
        return;
      }

      executeListeners(event.type, [event], defaultAction);

      return this;
    };

    self.trigger = function(eventName) {
      if (!_events[eventName] || _events[eventName].length === 0) {
        return;
      }

      var args = Array.prototype.slice.call(arguments);

      // Remove the eventName arg
      args.shift();

      executeListeners(eventName, args);

      return this;
    };

    self.on = function(eventNames, handlerOrContext, context) {
      if (typeof eventNames === "string" && handlerOrContext) {
        addListeners(eventNames.split(" "), handlerOrContext, context);
      } else {
        for (var name in eventNames) {
          if (eventNames.hasOwnProperty(name)) {
            addListeners([name], eventNames[name], handlerOrContext);
          }
        }
      }

      return this;
    };

    self.off = function(eventNames, handlerOrContext, context) {
      if (typeof eventNames === "string") {
        if (handlerOrContext && StringeeHelpers.isFunction(handlerOrContext)) {
          removeListeners(eventNames.split(" "), handlerOrContext, context);
        } else {
          StringeeHelpers.forEach(
            eventNames.split(" "),
            function(name) {
              removeAllListenersNamed(name, handlerOrContext);
            },
            this
          );
        }
      } else if (!eventNames) {
        // remove all bound events
        _events = {};
      } else {
        for (var name in eventNames) {
          if (eventNames.hasOwnProperty(name)) {
            removeListeners([name], eventNames[name], handlerOrContext);
          }
        }
      }

      return this;
    };

    self.once = function(eventNames, handler, context) {
      var names = eventNames.split(" "),
        fun = StringeeHelpers.bind(function() {
          var result = handler.apply(context || null, arguments);
          removeListeners(names, handler, context);

          return result;
        }, this);

      addListeners(names, handler, context, fun);
      return this;
    };
  };
})(window, window.StringeeHelpers);
