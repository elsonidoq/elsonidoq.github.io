class HistoryKeeper
    constructor: () ->
        @boundingBox = minX: 0, minY: 0, maxX: 0, maxY: 0
        @currentPosition = x:0, y:0
        @currentAngle= Math.PI/2
        @stateHistory = []

    setCurrentPosition: (position) ->
        @currentPosition = _.clone position

    saveState: (action=null) ->
        @stateHistory.push angle: @currentAngle, action: action, position: _.clone @currentPosition

    rotate: (degrees) ->
        @saveState('rotate ' + degrees)
        @currentAngle += degrees * Math.PI / 180

    forward: (length) ->
        @saveState('forward ' + length)

        @currentPosition.x = @currentPosition.x - length * Math.cos @currentAngle
        @currentPosition.y = @currentPosition.y - length * Math.sin @currentAngle

        @boundingBox.minX = Math.min @currentPosition.x, @boundingBox.minX
        @boundingBox.minY = Math.min @currentPosition.y, @boundingBox.minY
        @boundingBox.maxX = Math.max @currentPosition.x, @boundingBox.maxX
        @boundingBox.maxY = Math.max @currentPosition.y, @boundingBox.maxY
        @

    pop: (other) ->
        # other is inside history keeper 
        @boundingBox = mergeBoundingBoxes @boundingBox, other.boundingBox
        @stateHistory = @stateHistory.concat other.stateHistory
        @

mergeBoundingBoxes = (b1, b2) ->
    if _.isNull b1.maxY
        return _.clone b2
    else if _.isNull b2.maxY
        return _.clone b1
    else
        return {minX: Math.min(b1.minX, b2.minX), maxX: Math.max(b1.maxX, b2.maxX), minY: Math.min(b1.minY, b2.minY), maxY: Math.max(b1.maxY, b2.maxY)}
    
        
class Stack
    # A generic stack

    constructor: () ->
        @size = 0
        @grow_size = 10
        @contents = Array(@grow_size)

    push: (item) ->
        if @contents.length > @size
            @contents[@size++] = item
        else
            @contents.length += @grow_size
            @contents[@size++] = item

    pop: ->
        if @size == 0
            return

        elem = @contents[@size - 1]
        delete @contents[@size - 1]
        @size--
        return elem

    peek: ->
        if @size > 0
            return @contents[@size - 1]


class LSystem
    # A representation of a single L system.

    constructor: (hash, canvas, lineColor=null) ->

        @canvas= canvas
        @axiom = hash.axiom
        @rules = hash.rules
        @renderFunctions = hash.renderFunctions
        @postStep = hash.postStep
        @preStep = hash.preStep
        @stack = new Stack(@axiom, @rules, @renderFunctions)
        @stack.push new Turtle(new HistoryKeeper(), canvas=canvas)
        @stepNumber = 0
        @lineColor = lineColor or '#FFF'

    step: () ->
        buffer = ''

        if @preStep?
            buffer = @preStep(buffer, @stepNumber)

        for i in [0..@axiom.length - 1]
            char = @axiom.charAt i
            # todo: handle constants that don't have a translation function
            generationFunc = @rules[char]

            if generationFunc
                buffer = buffer + generationFunc
            else
                buffer = buffer + char
        
        @stepNumber++
        if @postStep?
            buffer = @postStep(buffer, @stepNumber)
        return buffer


    render: () ->
        n = 0
        ctx = @canvas.getContext '2d'
        ctx.strokeStyle = @lineColor

        #console.log @axiom.length
        symbol = ''
        for i in [0..@axiom.length - 1]
            symbol += @axiom[i] #start..i]
            if symbol not of @renderFunctions
                continue
            renderFunc = @renderFunctions[symbol]
            symbol = ''
            renderFunc(@stack)
            n++
            
        @
        

class Turtle
    # A simple implementation of Turtle Graphics.

    constructor: (historyKeeper, canvas) ->
        @canvas = canvas
        @ctx = canvas.getContext '2d'
        @drawing = true
        @historyKeeper = historyKeeper

    penDown: ->
        @drawing = true

    penUp: ->
        @drawing = false

    rotate: (degrees) ->
        @ctx.moveTo 0, 0
        @ctx.rotate degrees * Math.PI / 180
        @historyKeeper.rotate degrees

    forward: (length) ->
        @ctx.beginPath()
        @ctx.moveTo 0, 0

        if @drawing
            @ctx.lineTo 0, -length

        @ctx.stroke()

        @ctx.translate 0, -length

        @historyKeeper.forward length
        @


    right: (degrees) ->
        @rotate degrees
        @

    left: (degrees) ->
        @right -degrees
        @
    
currentSystem = undefined

class TransformState
    changeZoomLevel: (newZoom) ->
        @xOffset/= @zoomLevel/newZoom
        @yOffset/= @zoomLevel/newZoom
        @zoomLevel = newZoom

    zoomOut: (amount) ->
        @changeZoomLevel @zoomLevel*amount
        $("#zoom-factor").val @zoomLevel

    zoomIn: (amount) ->
        @changeZoomLevel @zoomLevel/amount
        $("#zoom-factor").val @zoomLevel
        
    xOffset: 0
    yOffset: 0
    zoomLevel: 1.0


class LSystemView
    constructor: (systemSpec, canvas=null, transformState=null, maxLineWidth=null, backgroundColor=null, lineColor=null) ->
        @canvas=canvas
        @systemSpec = systemSpec
        @system = null
        @transformState = transformState or new TransformState()
        @maxLineWidth = maxLineWidth
        @backgroundColor = backgroundColor or 'black'
        @lineColor = lineColor
        @
    
    recompute: (hash = null, numIterations=null) =>
        @system = new LSystem(@systemSpec, @canvas, @lineColor)
        if hash?
            @system.axiom = hash

        numIterations = numIterations or 1 #parseInt $("#numIterations").val() or 1

        for num in [1..numIterations]
            @step()

    step: =>
        @system.axiom = @system.step()

    clearCanvas: =>
        ctx = @canvas.getContext '2d'

        topX = (-@transformState.xOffset) / @transformState.zoomLevel
        topY = (-@transformState.yOffset) / @transformState.zoomLevel
        width = @canvas.width / @transformState.zoomLevel
        height = @canvas.height / @transformState.zoomLevel

        ctx.setTransform(@transformState.zoomLevel, 0, 0, @transformState.zoomLevel, @transformState.xOffset, @transformState.yOffset)
        ctx.fillStyle = @backgroundColor
        ctx.fillRect topX, topY, width, height

    redraw: (clearCanvas = true) =>
        ctx = @canvas.getContext '2d'
        if clearCanvas
            @clearCanvas()
        else
            ctx.setTransform(@transformState.zoomLevel, 0, 0, @transformState.zoomLevel, @transformState.xOffset, @transformState.yOffset)
        if @maxLineWidth?
            ctx.lineWidth = Math.min @maxLineWidth, 2*Math.floor 1.0/@transformState.zoomLevel
        else
            ctx.lineWidth = 2*Math.floor 1.0/@transformState.zoomLevel
        #ctx.lineWidth = 0.1

        ctx.setTransform(@transformState.zoomLevel, 0, 0, @transformState.zoomLevel, @transformState.xOffset, @transformState.yOffset)

        @system.stack.pop()
        @system.stack.push new Turtle(new HistoryKeeper(),canvas=@canvas)
        @system.render()
        ctx.setTransform(@transformState.zoomLevel, 0, 0, @transformState.zoomLevel, @transformState.xOffset, @transformState.yOffset)

        #img = $('#canvas')[0].toDataURL("image/png")
        #uriContent = "data:application/octet-stream," + encodeURIComponent(img)
        #$("#download").attr 'href', img
        #$("#download").attr 'download', 'pepe.png'
    
    fitToCanvas: (zoomLevelFactor=0.9)=>
        ctx = @canvas.getContext '2d'

        boundingBox = @system.stack.pop().historyKeeper.boundingBox
        @system.stack.push new Turtle( new HistoryKeeper(),canvas=@canvas)

        boundingBoxWidth = boundingBox.maxX - boundingBox.minX
        boundingBoxHeight = boundingBox.maxY - boundingBox.minY
        zoomLevel = Math.min @canvas.width/boundingBoxWidth, @canvas.height/boundingBoxHeight
        zoomLevel = zoomLevel*zoomLevelFactor

        @transformState.zoomLevel = zoomLevel
        @transformState.xOffset = -boundingBox.minX*zoomLevel + (@canvas.width - boundingBoxWidth*zoomLevel)/2
        @transformState.yOffset = -boundingBox.minY*zoomLevel + (@canvas.height - boundingBoxHeight*zoomLevel)/2

        $("#zoom-factor").val zoomLevel
        @redraw()

    getImage: =>
        ctx = @canvas.getContext '2d'

        return ctx.getImageData 0, 0, canvas.width, canvas.height

        
    getChunkAxiom: (chunk, startingAngle) ->
        prefix = ''
        while startingAngle <= 0
            startingAngle = startingAngle + 360
        if startingAngle > 90
            while startingAngle > 90
                prefix = prefix + '-'
                #XXX system dependent
                startingAngle = startingAngle - 45
        else if startingAngle < 90
            if startingAngle == 45
                prefix = '+'
            else
                prefix = '++'
        return prefix + chunk
        
            


count = (str, chr) ->
    return _.filter(str, (e) -> e==chr).length

 expandChunk = (axiom, start, end, ruleNumber) ->
    #newEnd = end
    #for i in [end..start]
    #    if axiom[i] in ['[',']','+','-'] # no consume
    #        newEnd--
    #    else
    #        break
    #end = newEnd

    pushs = 0
    pops = 0
    newStart = start
    for i in [start..end]
        if axiom[i] == '['
            pushs++
        else if axiom[i] == ']'
            pops++
        
        while pops > pushs and newStart > 0
            newStart--
            if axiom[newStart] == '['
                pushs++
            else if axiom[newStart] == ']'
                pops++

    pushs = 0
    pops = 0
    newEnd = end
    for i in [end..newStart]
        if axiom[i] == '['
            pushs++
        else if axiom[i] == ']'
            pops++

        while pushs > pops and newEnd < axiom.length
            newEnd++
            # XXX no se banca cosas multichar
            ruleNumber++
            if axiom[newEnd] == '['
                pushs++
            else if axiom[newEnd] == ']'
                pops++

    chunk = axiom[newStart..newEnd]
    if count(chunk, '[') != count(chunk, ']')
        debugger
    return chunkStart: newStart, chunkEnd: newEnd, chunk: chunk, ruleNumber: ruleNumber

getColor = (n) ->
    start = 0
    end = 50
    hue = 224+(Math.abs n - 4) *15/9
    hsv = hue:hue, sat:50, val:50
    return hsv2rgb hsv

defaultSystem =

lsystems =
    'sandbox-teselado':
        axiom: '[S]T'
        maxLineWidth: 1
        rules:
            'X': '[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A'
            'S': 'X++X[--S]++X++X--S+S'
            'T': 'X++[--F+F--T]X++X++X--T+T'


        renderFunctions:
            'C0': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = getColor(0)
            'C1': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = getColor(1)

            'C2': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = getColor(2)

            'C3': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = getColor(3)

            'C4': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = getColor(4)

            'C5': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = getColor(5)

            'C6': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = getColor(6)

            'C7': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = getColor(7)

            'C8': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = getColor(8)

            'T': (stack) ->
                1

            'S': (stack) ->
                1

            'X': (stack) ->
                1

            'A': (stack) ->
                turtle = stack.peek()
                turtle.forward 10

            'F': (stack) ->
                turtle = stack.peek()
                turtle.penUp()
                turtle.forward 10
                turtle.penDown()

            '+': (stack) ->
                turtle = stack.peek()
                turtle.left 45

            '-': (stack) ->
                turtle = stack.peek()
                turtle.right 45


            '[': (stack) ->
                stack.peek().historyKeeper.saveState()
                historyKeeper = new HistoryKeeper()
                historyKeeper.setCurrentPosition stack.peek().historyKeeper.currentPosition
                historyKeeper.currentAngle =  stack.peek().historyKeeper.currentAngle
                turtle = new Turtle(historyKeeper,canvas=stack.peek().canvas)
                stack.push turtle
                turtle.ctx.save()

            ']': (stack) ->
                turtle = stack.pop()
                turtle.ctx.restore()
                turtle.historyKeeper.saveState()
                stack.peek().historyKeeper.pop turtle.historyKeeper
    'sandbox-logo':
        axiom: 'X'
        rules:
            'X': '-----F++F[-F]++F++F---F-F++X'

        preStep: (axiom, n) ->
            if n == 0
                return 'C0' + axiom
            else
                return axiom

        postStep: (axiom, n) ->
            return axiom[0..axiom.length-2] + 'C' + n + 'X'

        renderFunctions:
            'C0': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = getColor(0)
            'C1': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = getColor(1)

            'C2': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = getColor(2)

            'C3': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = getColor(3)

            'C4': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = getColor(4)

            'C5': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = getColor(5)

            'C6': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = getColor(6)

            'C7': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = getColor(7)

            'C8': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = getColor(8)

                
            'X': (stack) ->
                1

            '+': (stack) ->
                turtle = stack.peek()
                turtle.left 45

            '-': (stack) ->
                turtle = stack.peek()
                turtle.right 45


            'F': (stack) ->
                turtle = stack.peek()
                turtle.forward 10

            '[': (stack) ->
                stack.peek().historyKeeper.saveState()
                historyKeeper = new HistoryKeeper()
                historyKeeper.setCurrentPosition stack.peek().historyKeeper.currentPosition
                historyKeeper.currentAngle =  stack.peek().historyKeeper.currentAngle
                turtle = new Turtle(historyKeeper,canvas=stack.peek().canvas)
                stack.push turtle
                turtle.ctx.save()

            ']': (stack) ->
                turtle = stack.pop()
                turtle.ctx.restore()
                turtle.historyKeeper.saveState()
                stack.peek().historyKeeper.pop turtle.historyKeeper

    'sandbox-tree':
        axiom: 'S'

        rules:
            'X': '[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A'
            #'S': 'WX++X++X++X--W[T-T-S][S]T+T+S'
            'S': 'WX++X++X++X--W[T-S]T+S'
            'W': 'AAAAA'
            'A': 'AA'

        renderFunctions:
            'T+': (stack) ->
                turtle = stack.peek()
                turtle.left 25

            'T-': (stack) ->
                turtle = stack.peek()
                turtle.right 25

            'S': (stack) ->
                turtle = stack.peek()
                #turtle.forward 10

            'W': (stack) ->
                turtle = stack.peek()
                #turtle.forward 10

            'X': (stack) ->
                turtle = stack.peek()
                #turtle.forward 10

            'A': (stack) ->
                turtle = stack.peek()
                turtle.forward 10

            'F': (stack) ->
                turtle = stack.peek()
                turtle.forward 10

            '+': (stack) ->
                turtle = stack.peek()
                turtle.left 45

            '-': (stack) ->
                turtle = stack.peek()
                turtle.right 45


            '[': (stack) ->
                stack.peek().historyKeeper.saveState()
                historyKeeper = new HistoryKeeper()
                historyKeeper.setCurrentPosition stack.peek().historyKeeper.currentPosition
                historyKeeper.currentAngle =  stack.peek().historyKeeper.currentAngle
                turtle = new Turtle(historyKeeper,canvas=stack.peek().canvas)
                stack.push turtle
                turtle.ctx.save()

            ']': (stack) ->
                turtle = stack.pop()
                turtle.ctx.restore()
                turtle.historyKeeper.saveState()
                stack.peek().historyKeeper.pop turtle.historyKeeper
    
    'sandbox-mandala-zommed':
        maxLineWidth: 6
        axiom: '[A][-A][--A][---A][----A][-----A][------A][-------A]'
        rules:
            'S': 'FFFF[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A--FFFF'
            'A': 'FASAF'
            'F':'FFF'

        renderFunctions:
            'S': (stack) ->
                turtle = stack.peek()
                turtle.forward 10

            'B': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = '#000'
                turtle.historyKeeper.saveState()

            'C1': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = '#0FF'
                turtle.historyKeeper.saveState()

            'C2': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = '#FFF'
                turtle.historyKeeper.saveState()

            'C3': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = '#88F'
                turtle.historyKeeper.saveState()

            'C4': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = '#F4F'
                turtle.historyKeeper.saveState()


            'F': (stack) ->
                turtle = stack.peek()
                turtle.forward 10

            'A': (stack) ->
                turtle = stack.peek()
                turtle.forward 10

            '[': (stack) ->
                stack.peek().historyKeeper.saveState()
                historyKeeper = new HistoryKeeper()
                historyKeeper.setCurrentPosition stack.peek().historyKeeper.currentPosition
                historyKeeper.currentAngle =  stack.peek().historyKeeper.currentAngle
                turtle = new Turtle(historyKeeper,canvas=stack.peek().canvas)
                stack.push turtle
                turtle.ctx.save()

            ']': (stack) ->
                turtle = stack.pop()
                turtle.ctx.restore()
                turtle.historyKeeper.saveState()
                stack.peek().historyKeeper.pop turtle.historyKeeper

            '+': (stack) ->
                turtle = stack.peek()
                turtle.left 45

            '-': (stack) ->
                turtle = stack.peek()
                turtle.right 45

    'sandbox-mandala':
        #axiom: '[--A+A][+A--A]-A++A-C1AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-C2AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-C3AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-C4AA[+A--A]-A++A+A+A--C1'
        maxLineWidth: 5
        axiom: '[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A--'
        rules:
            #'X': '+F--A[+A]--A--A+++A+A'
            #'S': 'WX++X++X++X++X++X++X++XA+AA+AA+AA+A--W'
            #'F': '+S--S[+S]--S--S+++S+S'
            'S': 'FFFF[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A--FFFF'
            'A': 'FASAF'
            'F':'FFF'

        renderFunctions:
            'S': (stack) ->
                turtle = stack.peek()
                turtle.forward 10

            'B': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = '#000'
                turtle.historyKeeper.saveState()

            'C1': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = '#0FF'
                turtle.historyKeeper.saveState()

            'C2': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = '#FFF'
                turtle.historyKeeper.saveState()

            'C3': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = '#88F'
                turtle.historyKeeper.saveState()

            'C4': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = '#F4F'
                turtle.historyKeeper.saveState()


            'F': (stack) ->
                turtle = stack.peek()
                turtle.forward 10

            'A': (stack) ->
                turtle = stack.peek()
                turtle.forward 10

            '[': (stack) ->
                stack.peek().historyKeeper.saveState()
                historyKeeper = new HistoryKeeper()
                historyKeeper.setCurrentPosition stack.peek().historyKeeper.currentPosition
                historyKeeper.currentAngle =  stack.peek().historyKeeper.currentAngle
                turtle = new Turtle(historyKeeper,canvas=stack.peek().canvas)
                stack.push turtle
                turtle.ctx.save()

            ']': (stack) ->
                turtle = stack.pop()
                turtle.ctx.restore()
                turtle.historyKeeper.saveState()
                stack.peek().historyKeeper.pop turtle.historyKeeper

            '+': (stack) ->
                turtle = stack.peek()
                turtle.left 45

            '-': (stack) ->
                turtle = stack.peek()
                turtle.right 45
    'Test':
        #axiom: '+++++++++GFFEFF'
        axiom: '+GFFEFF'
        #axiom: 'FF-FF-F[-F+F]F-FF-FF-FF-FF-FF'
        #axiom: 'FF[-FF++FF]+FF--FF'
        #axiom: 'CFGF'
        #axiom: '----EF--G'
        rules: {}
        renderFunctions:
            'C': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = '#0FF'
                turtle.historyKeeper.saveState('C')

            'G': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = '#0F0'
                turtle.historyKeeper.saveState('G')

            'E': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = '#FFF'
                turtle.historyKeeper.saveState('E')

            'D': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = '#F0F'
                turtle.historyKeeper.saveState('D')

            'F': (stack) ->
                turtle = stack.peek()
                turtle.forward 10

            '-': (stack) ->
                turtle = stack.peek()

                turtle.right 45
            '+': (stack) ->
                turtle = stack.peek()
                turtle.left 45
                
            '[': (stack) ->
                stack.peek().historyKeeper.saveState('[')
                historyKeeper = new HistoryKeeper()
                historyKeeper.setCurrentPosition stack.peek().historyKeeper.currentPosition
                historyKeeper.currentAngle =  stack.peek().historyKeeper.currentAngle
                turtle = new Turtle(historyKeeper,canvas=stack.peek().canvas)
                stack.push turtle
                turtle.ctx.save()

            ']': (stack) ->
                turtle = stack.pop()
                turtle.ctx.restore()
                turtle.historyKeeper.saveState(']')
                stack.peek().historyKeeper.pop turtle.historyKeeper
            
    'Sierpinski Triangle':
        axiom: 'A'
        rules:
            'A': 'B-A-B'
            'B': 'A+B+A'
        renderFunctions:
            'A': (stack) ->
                turtle = stack.peek()
                turtle.forward 10
            'B': (stack) ->
                turtle = stack.peek()
                turtle.forward 10
            '-': (stack) ->
                turtle = stack.peek()
                turtle.left 60
            '+': (stack) ->
                turtle = stack.peek()
                turtle.right 60
    'Wikipedia Example 2':
        axiom: '0'
        rules:
            '1': '11'
            '0': '1[0]0'
        renderFunctions:
            '0': (stack) ->
                turtle = stack.peek()
                turtle.forward 10
            '1': (stack) ->
                turtle = stack.peek()
                turtle.forward 10
            '[': (stack) ->
                stack.peek().historyKeeper.saveState()
                historyKeeper = new HistoryKeeper()
                historyKeeper.setCurrentPosition stack.peek().historyKeeper.currentPosition
                historyKeeper.currentAngle =  stack.peek().historyKeeper.currentAngle
                turtle = new Turtle(historyKeeper,canvas=stack.peek().canvas)
                stack.push turtle
                turtle.ctx.save()

            ']': (stack) ->
                turtle = stack.pop()
                turtle.ctx.restore()
                turtle.historyKeeper.saveState()
                stack.peek().historyKeeper.pop turtle.historyKeeper
    'Koch Snowflake':
        axiom: 'S--S--S'
        rules:
            'S': 'S+S--S+S'
        renderFunctions:
            'S': (stack) ->
                turtle = stack.peek()
                turtle.forward 10
            '+': (stack) ->
                turtle = stack.peek()
                turtle.left 60
            '-': (stack) ->
                turtle = stack.peek()
                turtle.right 60
    'Tree':
        axiom: 'F'
        rules:
            'F': 'F[+F]F[-F][F]'
        renderFunctions:
            'F': (stack) ->
                turtle = stack.peek()
                turtle.forward 10
            '[': (stack) ->
                turtle = new Turtle()
                stack.push turtle
                turtle.ctx.save()
            ']': (stack) ->
                turtle = stack.pop()
                turtle.ctx.restore()
            '+': (stack) ->
                turtle = stack.peek()
                turtle.left 20
            '-': (stack) ->
                turtle = stack.peek()
                turtle.right 20

drawFractal = (container, systemName, transformState=null, initialSteps=null, backgroundColor=null, lineColor=null) ->
    canvas = container.find('canvas')[0]
    maxLineWidth = null
    if lsystems[systemName].maxLineWidth?
        maxLineWidth = lsystems[systemName].maxLineWidth

    lsView = new LSystemView(lsystems[systemName], canvas, transformState, maxLineWidth, backgroundColor, lineColor)

    container.find("#step").click =>
            lsView.step()
            lsView.redraw()
            lsView.fitToCanvas()

    ctx = canvas.getContext '2d'

    container.find('#zoomIn').click ->
        lsView.transformState.zoomIn 0.6
        ctx.scale lsView.transformState.zoomLevel, lsView.transformState.zoomLevel
        lsView.redraw()

    container.find('#zoomOut').click ->
        lsView.transformState.zoomOut 0.6
        ctx.scale lsView.transformState.zoomLevel, lsView.transformState.zoomLevel
        lsView.redraw()


    container.find("#fitToCanvas").click ->
        lsView.fitToCanvas()

    container.find("#setZoom").click ->
        lsView.transformState.zoomLevel = parseFloat($("#zoom-factor").val())
        ctx.scale lsView.transformState.zoomLevel, lsView.transformState.zoomLevel
        lsView.redraw()

    previousX = 0
    previousY = 0
    dragging = false

    canvas.onmousedown = (event) ->
        previousX = event.offsetX
        previousY = event.offsetY
        dragging = true

    canvas.onmouseup = (event) ->
        dragging = false

    canvas.onmousemove = (event) ->
        if dragging
            lsView.transformState.xOffset += event.offsetX - previousX
            lsView.transformState.yOffset += event.offsetY - previousY

            previousX = event.offsetX
            previousY = event.offsetY
            lsView.redraw()



    lsView.recompute(null, initialSteps)
    lsView.redraw()
    return lsView
    
lsView = null

initialise = ->
    selectBox = document.getElementById 'systemselector'
    for key in Object.keys(lsystems)
        selectBox.options[selectBox.options.length] = new Option(key)

    currentSystem = Object.keys(lsystems)[0]
    container = $(".container")
    lsView = drawFractal container, currentSystem

    container.find("#submitButton").click =>
            currentSystem = selectBox.value
            canvas = container.find('canvas')[0]
            lsView = new LSystemView(lsystems[currentSystem], canvas = canvas)
            lsView = drawFractal container, currentSystem
            lsView.fitToCanvas()
    
    lsView.fitToCanvas()
