// Generated by CoffeeScript 1.7.1
var HistoryKeeper, LSystem, LSystemView, Stack, TransformState, Turtle, count, currentSystem, defaultSystem, drawFractal, expandChunk, getColor, initialise, lsView, lsystems, mergeBoundingBoxes,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

HistoryKeeper = (function() {
  function HistoryKeeper() {
    this.boundingBox = {
      minX: 0,
      minY: 0,
      maxX: 0,
      maxY: 0
    };
    this.currentPosition = {
      x: 0,
      y: 0
    };
    this.currentAngle = Math.PI / 2;
    this.stateHistory = [];
  }

  HistoryKeeper.prototype.setCurrentPosition = function(position) {
    return this.currentPosition = _.clone(position);
  };

  HistoryKeeper.prototype.saveState = function(action) {
    if (action == null) {
      action = null;
    }
    return this.stateHistory.push({
      angle: this.currentAngle,
      action: action,
      position: _.clone(this.currentPosition)
    });
  };

  HistoryKeeper.prototype.rotate = function(degrees) {
    this.saveState('rotate ' + degrees);
    return this.currentAngle += degrees * Math.PI / 180;
  };

  HistoryKeeper.prototype.forward = function(length) {
    this.saveState('forward ' + length);
    this.currentPosition.x = this.currentPosition.x - length * Math.cos(this.currentAngle);
    this.currentPosition.y = this.currentPosition.y - length * Math.sin(this.currentAngle);
    this.boundingBox.minX = Math.min(this.currentPosition.x, this.boundingBox.minX);
    this.boundingBox.minY = Math.min(this.currentPosition.y, this.boundingBox.minY);
    this.boundingBox.maxX = Math.max(this.currentPosition.x, this.boundingBox.maxX);
    this.boundingBox.maxY = Math.max(this.currentPosition.y, this.boundingBox.maxY);
    return this;
  };

  HistoryKeeper.prototype.pop = function(other) {
    this.boundingBox = mergeBoundingBoxes(this.boundingBox, other.boundingBox);
    this.stateHistory = this.stateHistory.concat(other.stateHistory);
    return this;
  };

  return HistoryKeeper;

})();

mergeBoundingBoxes = function(b1, b2) {
  if (_.isNull(b1.maxY)) {
    return _.clone(b2);
  } else if (_.isNull(b2.maxY)) {
    return _.clone(b1);
  } else {
    return {
      minX: Math.min(b1.minX, b2.minX),
      maxX: Math.max(b1.maxX, b2.maxX),
      minY: Math.min(b1.minY, b2.minY),
      maxY: Math.max(b1.maxY, b2.maxY)
    };
  }
};

Stack = (function() {
  function Stack() {
    this.size = 0;
    this.grow_size = 10;
    this.contents = Array(this.grow_size);
  }

  Stack.prototype.push = function(item) {
    if (this.contents.length > this.size) {
      return this.contents[this.size++] = item;
    } else {
      this.contents.length += this.grow_size;
      return this.contents[this.size++] = item;
    }
  };

  Stack.prototype.pop = function() {
    var elem;
    if (this.size === 0) {
      return;
    }
    elem = this.contents[this.size - 1];
    delete this.contents[this.size - 1];
    this.size--;
    return elem;
  };

  Stack.prototype.peek = function() {
    if (this.size > 0) {
      return this.contents[this.size - 1];
    }
  };

  return Stack;

})();

LSystem = (function() {
  function LSystem(hash, canvas, lineColor) {
    if (lineColor == null) {
      lineColor = null;
    }
    this.canvas = canvas;
    this.axiom = hash.axiom;
    this.rules = hash.rules;
    this.renderFunctions = hash.renderFunctions;
    this.postStep = hash.postStep;
    this.preStep = hash.preStep;
    this.stack = new Stack(this.axiom, this.rules, this.renderFunctions);
    this.stack.push(new Turtle(new HistoryKeeper(), canvas = canvas));
    this.stepNumber = 0;
    this.lineColor = lineColor || '#FFF';
  }

  LSystem.prototype.step = function() {
    var buffer, char, generationFunc, i, _i, _ref;
    buffer = '';
    if (this.preStep != null) {
      buffer = this.preStep(buffer, this.stepNumber);
    }
    for (i = _i = 0, _ref = this.axiom.length - 1; 0 <= _ref ? _i <= _ref : _i >= _ref; i = 0 <= _ref ? ++_i : --_i) {
      char = this.axiom.charAt(i);
      generationFunc = this.rules[char];
      if (generationFunc) {
        buffer = buffer + generationFunc;
      } else {
        buffer = buffer + char;
      }
    }
    this.stepNumber++;
    if (this.postStep != null) {
      buffer = this.postStep(buffer, this.stepNumber);
    }
    return buffer;
  };

  LSystem.prototype.render = function() {
    var ctx, i, n, renderFunc, symbol, _i, _ref;
    n = 0;
    ctx = this.canvas.getContext('2d');
    ctx.strokeStyle = this.lineColor;
    symbol = '';
    for (i = _i = 0, _ref = this.axiom.length - 1; 0 <= _ref ? _i <= _ref : _i >= _ref; i = 0 <= _ref ? ++_i : --_i) {
      symbol += this.axiom[i];
      if (!(symbol in this.renderFunctions)) {
        continue;
      }
      renderFunc = this.renderFunctions[symbol];
      symbol = '';
      renderFunc(this.stack);
      n++;
    }
    return this;
  };

  return LSystem;

})();

Turtle = (function() {
  function Turtle(historyKeeper, canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.drawing = true;
    this.historyKeeper = historyKeeper;
  }

  Turtle.prototype.penDown = function() {
    return this.drawing = true;
  };

  Turtle.prototype.penUp = function() {
    return this.drawing = false;
  };

  Turtle.prototype.rotate = function(degrees) {
    this.ctx.moveTo(0, 0);
    this.ctx.rotate(degrees * Math.PI / 180);
    return this.historyKeeper.rotate(degrees);
  };

  Turtle.prototype.forward = function(length) {
    this.ctx.beginPath();
    this.ctx.moveTo(0, 0);
    if (this.drawing) {
      this.ctx.lineTo(0, -length);
    }
    this.ctx.stroke();
    this.ctx.translate(0, -length);
    this.historyKeeper.forward(length);
    return this;
  };

  Turtle.prototype.right = function(degrees) {
    this.rotate(degrees);
    return this;
  };

  Turtle.prototype.left = function(degrees) {
    this.right(-degrees);
    return this;
  };

  return Turtle;

})();

currentSystem = void 0;

TransformState = (function() {
  function TransformState() {}

  TransformState.prototype.changeZoomLevel = function(newZoom) {
    this.xOffset /= this.zoomLevel / newZoom;
    this.yOffset /= this.zoomLevel / newZoom;
    return this.zoomLevel = newZoom;
  };

  TransformState.prototype.zoomOut = function(amount) {
    this.changeZoomLevel(this.zoomLevel * amount);
    return $("#zoom-factor").val(this.zoomLevel);
  };

  TransformState.prototype.zoomIn = function(amount) {
    this.changeZoomLevel(this.zoomLevel / amount);
    return $("#zoom-factor").val(this.zoomLevel);
  };

  TransformState.prototype.xOffset = 0;

  TransformState.prototype.yOffset = 0;

  TransformState.prototype.zoomLevel = 1.0;

  return TransformState;

})();

LSystemView = (function() {
  function LSystemView(systemSpec, canvas, transformState, maxLineWidth, backgroundColor, lineColor) {
    if (canvas == null) {
      canvas = null;
    }
    if (transformState == null) {
      transformState = null;
    }
    if (maxLineWidth == null) {
      maxLineWidth = null;
    }
    if (backgroundColor == null) {
      backgroundColor = null;
    }
    if (lineColor == null) {
      lineColor = null;
    }
    this.getImage = __bind(this.getImage, this);
    this.fitToCanvas = __bind(this.fitToCanvas, this);
    this.redraw = __bind(this.redraw, this);
    this.clearCanvas = __bind(this.clearCanvas, this);
    this.step = __bind(this.step, this);
    this.recompute = __bind(this.recompute, this);
    this.canvas = canvas;
    this.systemSpec = systemSpec;
    this.system = null;
    this.transformState = transformState || new TransformState();
    this.maxLineWidth = maxLineWidth;
    this.backgroundColor = backgroundColor || 'black';
    this.lineColor = lineColor;
    this;
  }

  LSystemView.prototype.recompute = function(hash, numIterations) {
    var num, _i, _results;
    if (hash == null) {
      hash = null;
    }
    if (numIterations == null) {
      numIterations = null;
    }
    this.system = new LSystem(this.systemSpec, this.canvas, this.lineColor);
    if (hash != null) {
      this.system.axiom = hash;
    }
    numIterations = numIterations || 1;
    _results = [];
    for (num = _i = 1; 1 <= numIterations ? _i <= numIterations : _i >= numIterations; num = 1 <= numIterations ? ++_i : --_i) {
      _results.push(this.step());
    }
    return _results;
  };

  LSystemView.prototype.step = function() {
    return this.system.axiom = this.system.step();
  };

  LSystemView.prototype.clearCanvas = function() {
    var ctx, height, topX, topY, width;
    ctx = this.canvas.getContext('2d');
    topX = (-this.transformState.xOffset) / this.transformState.zoomLevel;
    topY = (-this.transformState.yOffset) / this.transformState.zoomLevel;
    width = this.canvas.width / this.transformState.zoomLevel;
    height = this.canvas.height / this.transformState.zoomLevel;
    ctx.setTransform(this.transformState.zoomLevel, 0, 0, this.transformState.zoomLevel, this.transformState.xOffset, this.transformState.yOffset);
    ctx.fillStyle = this.backgroundColor;
    return ctx.fillRect(topX, topY, width, height);
  };

  LSystemView.prototype.redraw = function(clearCanvas) {
    var canvas, ctx;
    if (clearCanvas == null) {
      clearCanvas = true;
    }
    ctx = this.canvas.getContext('2d');
    if (clearCanvas) {
      this.clearCanvas();
    } else {
      ctx.setTransform(this.transformState.zoomLevel, 0, 0, this.transformState.zoomLevel, this.transformState.xOffset, this.transformState.yOffset);
    }
    if (this.maxLineWidth != null) {
      ctx.lineWidth = Math.min(this.maxLineWidth, 2 * Math.floor(1.0 / this.transformState.zoomLevel));
    } else {
      ctx.lineWidth = 2 * Math.floor(1.0 / this.transformState.zoomLevel);
    }
    ctx.setTransform(this.transformState.zoomLevel, 0, 0, this.transformState.zoomLevel, this.transformState.xOffset, this.transformState.yOffset);
    this.system.stack.pop();
    this.system.stack.push(new Turtle(new HistoryKeeper(), canvas = this.canvas));
    this.system.render();
    return ctx.setTransform(this.transformState.zoomLevel, 0, 0, this.transformState.zoomLevel, this.transformState.xOffset, this.transformState.yOffset);
  };

  LSystemView.prototype.fitToCanvas = function(zoomLevelFactor) {
    var boundingBox, boundingBoxHeight, boundingBoxWidth, canvas, ctx, zoomLevel;
    if (zoomLevelFactor == null) {
      zoomLevelFactor = 0.9;
    }
    ctx = this.canvas.getContext('2d');
    boundingBox = this.system.stack.pop().historyKeeper.boundingBox;
    this.system.stack.push(new Turtle(new HistoryKeeper(), canvas = this.canvas));
    boundingBoxWidth = boundingBox.maxX - boundingBox.minX;
    boundingBoxHeight = boundingBox.maxY - boundingBox.minY;
    zoomLevel = Math.min(this.canvas.width / boundingBoxWidth, this.canvas.height / boundingBoxHeight);
    zoomLevel = zoomLevel * zoomLevelFactor;
    this.transformState.zoomLevel = zoomLevel;
    this.transformState.xOffset = -boundingBox.minX * zoomLevel + (this.canvas.width - boundingBoxWidth * zoomLevel) / 2;
    this.transformState.yOffset = -boundingBox.minY * zoomLevel + (this.canvas.height - boundingBoxHeight * zoomLevel) / 2;
    $("#zoom-factor").val(zoomLevel);
    return this.redraw();
  };

  LSystemView.prototype.getImage = function() {
    var ctx;
    ctx = this.canvas.getContext('2d');
    return ctx.getImageData(0, 0, canvas.width, canvas.height);
  };

  LSystemView.prototype.getChunkAxiom = function(chunk, startingAngle) {
    var prefix;
    prefix = '';
    while (startingAngle <= 0) {
      startingAngle = startingAngle + 360;
    }
    if (startingAngle > 90) {
      while (startingAngle > 90) {
        prefix = prefix + '-';
        startingAngle = startingAngle - 45;
      }
    } else if (startingAngle < 90) {
      if (startingAngle === 45) {
        prefix = '+';
      } else {
        prefix = '++';
      }
    }
    return prefix + chunk;
  };

  return LSystemView;

})();

count = function(str, chr) {
  return _.filter(str, function(e) {
    return e === chr;
  }).length;
};

expandChunk = function(axiom, start, end, ruleNumber) {
  var chunk, i, newEnd, newStart, pops, pushs, _i, _j;
  pushs = 0;
  pops = 0;
  newStart = start;
  for (i = _i = start; start <= end ? _i <= end : _i >= end; i = start <= end ? ++_i : --_i) {
    if (axiom[i] === '[') {
      pushs++;
    } else if (axiom[i] === ']') {
      pops++;
    }
    while (pops > pushs && newStart > 0) {
      newStart--;
      if (axiom[newStart] === '[') {
        pushs++;
      } else if (axiom[newStart] === ']') {
        pops++;
      }
    }
  }
  pushs = 0;
  pops = 0;
  newEnd = end;
  for (i = _j = end; end <= newStart ? _j <= newStart : _j >= newStart; i = end <= newStart ? ++_j : --_j) {
    if (axiom[i] === '[') {
      pushs++;
    } else if (axiom[i] === ']') {
      pops++;
    }
    while (pushs > pops && newEnd < axiom.length) {
      newEnd++;
      ruleNumber++;
      if (axiom[newEnd] === '[') {
        pushs++;
      } else if (axiom[newEnd] === ']') {
        pops++;
      }
    }
  }
  chunk = axiom.slice(newStart, +newEnd + 1 || 9e9);
  if (count(chunk, '[') !== count(chunk, ']')) {
    debugger;
  }
  return {
    chunkStart: newStart,
    chunkEnd: newEnd,
    chunk: chunk,
    ruleNumber: ruleNumber
  };
};

getColor = function(n) {
  var end, hsv, hue, start;
  start = 0;
  end = 50;
  hue = 224 + (Math.abs(n - 4)) * 15 / 9;
  hsv = {
    hue: hue,
    sat: 50,
    val: 50
  };
  return hsv2rgb(hsv);
};

defaultSystem = lsystems = {
  'sandbox-teselado': {
    axiom: '[S]T',
    maxLineWidth: 1,
    rules: {
      'X': '[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A',
      'S': 'X++X[--S]++X++X--S+S',
      'T': 'X++[--F+F--T]X++X++X--T+T'
    },
    renderFunctions: {
      'C0': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.ctx.strokeStyle = getColor(0);
      },
      'C1': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.ctx.strokeStyle = getColor(1);
      },
      'C2': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.ctx.strokeStyle = getColor(2);
      },
      'C3': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.ctx.strokeStyle = getColor(3);
      },
      'C4': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.ctx.strokeStyle = getColor(4);
      },
      'C5': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.ctx.strokeStyle = getColor(5);
      },
      'C6': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.ctx.strokeStyle = getColor(6);
      },
      'C7': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.ctx.strokeStyle = getColor(7);
      },
      'C8': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.ctx.strokeStyle = getColor(8);
      },
      'T': function(stack) {
        return 1;
      },
      'S': function(stack) {
        return 1;
      },
      'X': function(stack) {
        return 1;
      },
      'A': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.forward(10);
      },
      'F': function(stack) {
        var turtle;
        turtle = stack.peek();
        turtle.penUp();
        turtle.forward(10);
        return turtle.penDown();
      },
      '+': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.left(45);
      },
      '-': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.right(45);
      },
      '[': function(stack) {
        var canvas, historyKeeper, turtle;
        stack.peek().historyKeeper.saveState();
        historyKeeper = new HistoryKeeper();
        historyKeeper.setCurrentPosition(stack.peek().historyKeeper.currentPosition);
        historyKeeper.currentAngle = stack.peek().historyKeeper.currentAngle;
        turtle = new Turtle(historyKeeper, canvas = stack.peek().canvas);
        stack.push(turtle);
        return turtle.ctx.save();
      },
      ']': function(stack) {
        var turtle;
        turtle = stack.pop();
        turtle.ctx.restore();
        turtle.historyKeeper.saveState();
        return stack.peek().historyKeeper.pop(turtle.historyKeeper);
      }
    }
  },
  'sandbox-logo': {
    axiom: 'X',
    rules: {
      'X': '-----F++F[-F]++F++F---F-F++X'
    },
    preStep: function(axiom, n) {
      if (n === 0) {
        return 'C0' + axiom;
      } else {
        return axiom;
      }
    },
    postStep: function(axiom, n) {
      return axiom.slice(0, +(axiom.length - 2) + 1 || 9e9) + 'C' + n + 'X';
    },
    renderFunctions: {
      'C0': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.ctx.strokeStyle = getColor(0);
      },
      'C1': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.ctx.strokeStyle = getColor(1);
      },
      'C2': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.ctx.strokeStyle = getColor(2);
      },
      'C3': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.ctx.strokeStyle = getColor(3);
      },
      'C4': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.ctx.strokeStyle = getColor(4);
      },
      'C5': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.ctx.strokeStyle = getColor(5);
      },
      'C6': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.ctx.strokeStyle = getColor(6);
      },
      'C7': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.ctx.strokeStyle = getColor(7);
      },
      'C8': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.ctx.strokeStyle = getColor(8);
      },
      'X': function(stack) {
        return 1;
      },
      '+': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.left(45);
      },
      '-': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.right(45);
      },
      'F': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.forward(10);
      },
      '[': function(stack) {
        var canvas, historyKeeper, turtle;
        stack.peek().historyKeeper.saveState();
        historyKeeper = new HistoryKeeper();
        historyKeeper.setCurrentPosition(stack.peek().historyKeeper.currentPosition);
        historyKeeper.currentAngle = stack.peek().historyKeeper.currentAngle;
        turtle = new Turtle(historyKeeper, canvas = stack.peek().canvas);
        stack.push(turtle);
        return turtle.ctx.save();
      },
      ']': function(stack) {
        var turtle;
        turtle = stack.pop();
        turtle.ctx.restore();
        turtle.historyKeeper.saveState();
        return stack.peek().historyKeeper.pop(turtle.historyKeeper);
      }
    }
  },
  'sandbox-tree': {
    axiom: 'S',
    rules: {
      'X': '[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A',
      'S': 'WX++X++X++X--W[T-S]T+S',
      'W': 'AAAAA',
      'A': 'AA'
    },
    renderFunctions: {
      'T+': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.left(25);
      },
      'T-': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.right(25);
      },
      'S': function(stack) {
        var turtle;
        return turtle = stack.peek();
      },
      'W': function(stack) {
        var turtle;
        return turtle = stack.peek();
      },
      'X': function(stack) {
        var turtle;
        return turtle = stack.peek();
      },
      'A': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.forward(10);
      },
      'F': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.forward(10);
      },
      '+': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.left(45);
      },
      '-': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.right(45);
      },
      '[': function(stack) {
        var canvas, historyKeeper, turtle;
        stack.peek().historyKeeper.saveState();
        historyKeeper = new HistoryKeeper();
        historyKeeper.setCurrentPosition(stack.peek().historyKeeper.currentPosition);
        historyKeeper.currentAngle = stack.peek().historyKeeper.currentAngle;
        turtle = new Turtle(historyKeeper, canvas = stack.peek().canvas);
        stack.push(turtle);
        return turtle.ctx.save();
      },
      ']': function(stack) {
        var turtle;
        turtle = stack.pop();
        turtle.ctx.restore();
        turtle.historyKeeper.saveState();
        return stack.peek().historyKeeper.pop(turtle.historyKeeper);
      }
    }
  },
  'sandbox-mandala-zommed': {
    maxLineWidth: 6,
    axiom: '[A][-A][--A][---A][----A][-----A][------A][-------A]',
    rules: {
      'S': 'FFFF[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A--FFFF',
      'A': 'FASAF',
      'F': 'FFF'
    },
    renderFunctions: {
      'S': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.forward(10);
      },
      'B': function(stack) {
        var turtle;
        turtle = stack.peek();
        turtle.ctx.strokeStyle = '#000';
        return turtle.historyKeeper.saveState();
      },
      'C1': function(stack) {
        var turtle;
        turtle = stack.peek();
        turtle.ctx.strokeStyle = '#0FF';
        return turtle.historyKeeper.saveState();
      },
      'C2': function(stack) {
        var turtle;
        turtle = stack.peek();
        turtle.ctx.strokeStyle = '#FFF';
        return turtle.historyKeeper.saveState();
      },
      'C3': function(stack) {
        var turtle;
        turtle = stack.peek();
        turtle.ctx.strokeStyle = '#88F';
        return turtle.historyKeeper.saveState();
      },
      'C4': function(stack) {
        var turtle;
        turtle = stack.peek();
        turtle.ctx.strokeStyle = '#F4F';
        return turtle.historyKeeper.saveState();
      },
      'F': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.forward(10);
      },
      'A': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.forward(10);
      },
      '[': function(stack) {
        var canvas, historyKeeper, turtle;
        stack.peek().historyKeeper.saveState();
        historyKeeper = new HistoryKeeper();
        historyKeeper.setCurrentPosition(stack.peek().historyKeeper.currentPosition);
        historyKeeper.currentAngle = stack.peek().historyKeeper.currentAngle;
        turtle = new Turtle(historyKeeper, canvas = stack.peek().canvas);
        stack.push(turtle);
        return turtle.ctx.save();
      },
      ']': function(stack) {
        var turtle;
        turtle = stack.pop();
        turtle.ctx.restore();
        turtle.historyKeeper.saveState();
        return stack.peek().historyKeeper.pop(turtle.historyKeeper);
      },
      '+': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.left(45);
      },
      '-': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.right(45);
      }
    }
  },
  'sandbox-mandala': {
    maxLineWidth: 5,
    axiom: '[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A--',
    rules: {
      'S': 'FFFF[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A--FFFF',
      'A': 'FASAF',
      'F': 'FFF'
    },
    renderFunctions: {
      'S': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.forward(10);
      },
      'B': function(stack) {
        var turtle;
        turtle = stack.peek();
        turtle.ctx.strokeStyle = '#000';
        return turtle.historyKeeper.saveState();
      },
      'C1': function(stack) {
        var turtle;
        turtle = stack.peek();
        turtle.ctx.strokeStyle = '#0FF';
        return turtle.historyKeeper.saveState();
      },
      'C2': function(stack) {
        var turtle;
        turtle = stack.peek();
        turtle.ctx.strokeStyle = '#FFF';
        return turtle.historyKeeper.saveState();
      },
      'C3': function(stack) {
        var turtle;
        turtle = stack.peek();
        turtle.ctx.strokeStyle = '#88F';
        return turtle.historyKeeper.saveState();
      },
      'C4': function(stack) {
        var turtle;
        turtle = stack.peek();
        turtle.ctx.strokeStyle = '#F4F';
        return turtle.historyKeeper.saveState();
      },
      'F': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.forward(10);
      },
      'A': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.forward(10);
      },
      '[': function(stack) {
        var canvas, historyKeeper, turtle;
        stack.peek().historyKeeper.saveState();
        historyKeeper = new HistoryKeeper();
        historyKeeper.setCurrentPosition(stack.peek().historyKeeper.currentPosition);
        historyKeeper.currentAngle = stack.peek().historyKeeper.currentAngle;
        turtle = new Turtle(historyKeeper, canvas = stack.peek().canvas);
        stack.push(turtle);
        return turtle.ctx.save();
      },
      ']': function(stack) {
        var turtle;
        turtle = stack.pop();
        turtle.ctx.restore();
        turtle.historyKeeper.saveState();
        return stack.peek().historyKeeper.pop(turtle.historyKeeper);
      },
      '+': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.left(45);
      },
      '-': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.right(45);
      }
    }
  },
  'Test': {
    axiom: '+GFFEFF',
    rules: {},
    renderFunctions: {
      'C': function(stack) {
        var turtle;
        turtle = stack.peek();
        turtle.ctx.strokeStyle = '#0FF';
        return turtle.historyKeeper.saveState('C');
      },
      'G': function(stack) {
        var turtle;
        turtle = stack.peek();
        turtle.ctx.strokeStyle = '#0F0';
        return turtle.historyKeeper.saveState('G');
      },
      'E': function(stack) {
        var turtle;
        turtle = stack.peek();
        turtle.ctx.strokeStyle = '#FFF';
        return turtle.historyKeeper.saveState('E');
      },
      'D': function(stack) {
        var turtle;
        turtle = stack.peek();
        turtle.ctx.strokeStyle = '#F0F';
        return turtle.historyKeeper.saveState('D');
      },
      'F': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.forward(10);
      },
      '-': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.right(45);
      },
      '+': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.left(45);
      },
      '[': function(stack) {
        var canvas, historyKeeper, turtle;
        stack.peek().historyKeeper.saveState('[');
        historyKeeper = new HistoryKeeper();
        historyKeeper.setCurrentPosition(stack.peek().historyKeeper.currentPosition);
        historyKeeper.currentAngle = stack.peek().historyKeeper.currentAngle;
        turtle = new Turtle(historyKeeper, canvas = stack.peek().canvas);
        stack.push(turtle);
        return turtle.ctx.save();
      },
      ']': function(stack) {
        var turtle;
        turtle = stack.pop();
        turtle.ctx.restore();
        turtle.historyKeeper.saveState(']');
        return stack.peek().historyKeeper.pop(turtle.historyKeeper);
      }
    }
  },
  'Sierpinski Triangle': {
    axiom: 'A',
    rules: {
      'A': 'B-A-B',
      'B': 'A+B+A'
    },
    renderFunctions: {
      'A': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.forward(10);
      },
      'B': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.forward(10);
      },
      '-': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.left(60);
      },
      '+': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.right(60);
      }
    }
  },
  'Wikipedia Example 2': {
    axiom: '0',
    rules: {
      '1': '11',
      '0': '1[0]0'
    },
    renderFunctions: {
      '0': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.forward(10);
      },
      '1': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.forward(10);
      },
      '[': function(stack) {
        var canvas, historyKeeper, turtle;
        stack.peek().historyKeeper.saveState();
        historyKeeper = new HistoryKeeper();
        historyKeeper.setCurrentPosition(stack.peek().historyKeeper.currentPosition);
        historyKeeper.currentAngle = stack.peek().historyKeeper.currentAngle;
        turtle = new Turtle(historyKeeper, canvas = stack.peek().canvas);
        stack.push(turtle);
        return turtle.ctx.save();
      },
      ']': function(stack) {
        var turtle;
        turtle = stack.pop();
        turtle.ctx.restore();
        turtle.historyKeeper.saveState();
        return stack.peek().historyKeeper.pop(turtle.historyKeeper);
      }
    }
  },
  'Koch Snowflake': {
    axiom: 'S--S--S',
    rules: {
      'S': 'S+S--S+S'
    },
    renderFunctions: {
      'S': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.forward(10);
      },
      '+': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.left(60);
      },
      '-': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.right(60);
      }
    }
  },
  'Tree': {
    axiom: 'F',
    rules: {
      'F': 'F[+F]F[-F][F]'
    },
    renderFunctions: {
      'F': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.forward(10);
      },
      '[': function(stack) {
        var turtle;
        turtle = new Turtle();
        stack.push(turtle);
        return turtle.ctx.save();
      },
      ']': function(stack) {
        var turtle;
        turtle = stack.pop();
        return turtle.ctx.restore();
      },
      '+': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.left(20);
      },
      '-': function(stack) {
        var turtle;
        turtle = stack.peek();
        return turtle.right(20);
      }
    }
  }
};

drawFractal = function(container, systemName, transformState, initialSteps, backgroundColor, lineColor) {
  var canvas, ctx, dragging, lsView, maxLineWidth, previousX, previousY;
  if (transformState == null) {
    transformState = null;
  }
  if (initialSteps == null) {
    initialSteps = null;
  }
  if (backgroundColor == null) {
    backgroundColor = null;
  }
  if (lineColor == null) {
    lineColor = null;
  }
  canvas = container.find('canvas')[0];
  maxLineWidth = null;
  if (lsystems[systemName].maxLineWidth != null) {
    maxLineWidth = lsystems[systemName].maxLineWidth;
  }
  lsView = new LSystemView(lsystems[systemName], canvas, transformState, maxLineWidth, backgroundColor, lineColor);
  container.find("#step").click((function(_this) {
    return function() {
      lsView.step();
      lsView.redraw();
      return lsView.fitToCanvas();
    };
  })(this));
  ctx = canvas.getContext('2d');
  container.find('#zoomIn').click(function() {
    lsView.transformState.zoomIn(0.6);
    ctx.scale(lsView.transformState.zoomLevel, lsView.transformState.zoomLevel);
    return lsView.redraw();
  });
  container.find('#zoomOut').click(function() {
    lsView.transformState.zoomOut(0.6);
    ctx.scale(lsView.transformState.zoomLevel, lsView.transformState.zoomLevel);
    return lsView.redraw();
  });
  container.find("#fitToCanvas").click(function() {
    return lsView.fitToCanvas();
  });
  container.find("#setZoom").click(function() {
    lsView.transformState.zoomLevel = parseFloat($("#zoom-factor").val());
    ctx.scale(lsView.transformState.zoomLevel, lsView.transformState.zoomLevel);
    return lsView.redraw();
  });
  previousX = 0;
  previousY = 0;
  dragging = false;
  canvas.onmousedown = function(event) {
    previousX = event.offsetX;
    previousY = event.offsetY;
    return dragging = true;
  };
  canvas.onmouseup = function(event) {
    return dragging = false;
  };
  canvas.onmousemove = function(event) {
    if (dragging) {
      lsView.transformState.xOffset += event.offsetX - previousX;
      lsView.transformState.yOffset += event.offsetY - previousY;
      previousX = event.offsetX;
      previousY = event.offsetY;
      return lsView.redraw();
    }
  };
  lsView.recompute(null, initialSteps);
  lsView.redraw();
  return lsView;
};

lsView = null;

initialise = function() {
  var container, key, selectBox, _i, _len, _ref;
  selectBox = document.getElementById('systemselector');
  _ref = Object.keys(lsystems);
  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
    key = _ref[_i];
    selectBox.options[selectBox.options.length] = new Option(key);
  }
  currentSystem = Object.keys(lsystems)[0];
  container = $(".container");
  lsView = drawFractal(container, currentSystem);
  container.find("#submitButton").click((function(_this) {
    return function() {
      var canvas;
      currentSystem = selectBox.value;
      canvas = container.find('canvas')[0];
      lsView = new LSystemView(lsystems[currentSystem], canvas = canvas);
      lsView = drawFractal(container, currentSystem);
      return lsView.fitToCanvas();
    };
  })(this));
  return lsView.fitToCanvas();
};
