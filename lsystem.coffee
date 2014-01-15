class HistoryKeeper
    constructor: () ->
        @boundingBox = minX: 0, minY: 0, maxX: 0, maxY: 0
        @currentPosition = x:0, y:0
        @currentAngle= Math.PI/2

    rotate: (degrees) ->
        @currentAngle += degrees * Math.PI / 180

    forward: (length) ->
        @currentPosition.x = @currentPosition.x + length * Math.cos @currentAngle
        @currentPosition.y = @currentPosition.y + length * Math.sin @currentAngle

        @boundingBox.minX = Math.min @currentPosition.x, @boundingBox.minX
        @boundingBox.minY = Math.min @currentPosition.y, @boundingBox.minY
        @boundingBox.maxX = Math.max @currentPosition.x, @boundingBox.maxX
        @boundingBox.maxY = Math.max @currentPosition.y, @boundingBox.maxY
        @
        
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

    constructor: (hash) ->

        @axiom = hash.axiom
        @rules = hash.rules
        @renderFunctions = hash.renderFunctions
        @stack = new Stack(@axiom, @rules, @renderFunctions)
        @stack.push new Turtle(new HistoryKeeper())

    step: () ->
        buffer = ''

        for i in [0..@axiom.length - 1]
            char = @axiom.charAt i
            # todo: handle constants that don't have a translation function
            generationFunc = @rules[char]

            if generationFunc
                buffer = buffer + generationFunc
            else
                buffer = buffer + char
        
        return buffer


    render: () ->
        start = 0
        for i in [0..@axiom.length - 1]
            char = @axiom[start..i]
            if char not of @renderFunctions
                continue
            renderFunc = @renderFunctions[char]
            start = i+1
            if renderFunc
                renderFunc(@stack)
        

class Turtle
    # A simple implementation of Turtle Graphics.

    constructor: (historyKeeper) ->
        canvas = document.getElementById("canvas")
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
transformState =
    zoomOut: (amount) ->
        @zoomLevel *= 0.9
        $("#zoom-factor").val @zoomLevel
    zoomIn: (amount) ->
        @zoomLevel /= 0.9
        $("#zoom-factor").val @zoomLevel
        
    xOffset: 0
    yOffset: 0
    zoomLevel: 1.0

class LSystemView
    constructor: (systemSpec) ->
        @systemSpec = systemSpec
        @system = null
        @
    
    recompute: (hash = null) =>
        @system = new LSystem(@systemSpec)
        if hash?
            @system.axiom = hash

        numIterations = parseInt $("#numIterations").val() or 1

        for num in [1..numIterations]
            @system.axiom = @system.step()

    redraw: =>
        canvas = $("#canvas")[0]
        ctx = canvas.getContext '2d'

        topX = -transformState.xOffset / transformState.zoomLevel
        topY = -transformState.yOffset / transformState.zoomLevel
        width = canvas.width / transformState.zoomLevel
        height = canvas.height / transformState.zoomLevel

        ctx.setTransform(transformState.zoomLevel, 0, 0, transformState.zoomLevel, transformState.xOffset, transformState.yOffset)
        ctx.fillStyle = 'black'
        ctx.fillRect topX, topY, width, height
        ctx.lineWidth = 2*Math.floor 1.0/transformState.zoomLevel

        @system.stack.pop()
        @system.stack.push new Turtle(new HistoryKeeper())
        @system.render()

        img = $('#canvas')[0].toDataURL("image/png")
        uriContent = "data:application/octet-stream," + encodeURIComponent(img)
        $("#download").attr 'href', img
        $("#download").attr 'download', 'pepe.png'
    
    fitToCanvas: =>
        canvas = $("#canvas")[0]
        ctx = canvas.getContext '2d'

        boundingBox = @system.stack.pop().historyKeeper.boundingBox
        console.log boundingBox
        @system.stack.push new Turtle( new HistoryKeeper())

        boundingBoxWidth = boundingBox.maxX - boundingBox.minX
        boundingBoxHeight = boundingBox.maxY - boundingBox.minY
        zoomLevel = Math.min canvas.width/boundingBoxWidth, canvas.height/boundingBoxHeight
        zoomLevel = zoomLevel*0.9

        transformState.zoomLevel = zoomLevel
        transformState.xOffset = boundingBoxWidth*zoomLevel/2
        transformState.yOffset = boundingBoxHeight*zoomLevel/2 + canvas.height/2

        $("#zoom-factor").val zoomLevel
        @redraw()

    getImage: =>
        canvas = $("#canvas")[0]
        ctx = canvas.getContext '2d'

        boundingBox = @system.stack.pop().historyKeeper.boundingBox
        @system.stack.push new Turtle(new HistoryKeeper())

        boundingBoxWidth = boundingBox.maxX - boundingBox.minX
        boundingBoxHeight = boundingBox.maxY - boundingBox.minY
        zoomLevel = Math.min canvas.width/boundingBoxWidth, canvas.height/boundingBoxHeight

        topX = -transformState.xOffset / transformState.zoomLevel
        topY = -transformState.yOffset / transformState.zoomLevel
        width = canvas.width / transformState.zoomLevel
        height = canvas.height / transformState.zoomLevel

        return ctx.getImageData topX, topY, width, height

        


        


lsystems =
    'Sandbox Mandala':
        #axiom: 'F-F-F-F-F-F-F-F'
        axiom: 'C1F--F--F--F-F'
        #axiom: 'C1[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++C2[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++C3[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++C4[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A--C1'
        rules:
            #'X': '+F--A[+A]--A--A+++A+A'
            #'S': 'WX++X++X++X++X++X++X++XA+AA+AA+AA+A--W'
            #'F': '+S--S[+S]--S--S+++S+S'
            'S': 'FFFF[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-AA[+A--A]-A++A+A+A--FFFF'
            'A': 'FASAF'
            'F':'FF[-F]F'

        renderFunctions:
            'S': (stack) ->
                turtle = stack.peek()
                turtle.forward 10

            'B': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = '#000'

            'C1': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = '#0FF'

            'C2': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = '#4CF'

            'C3': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = '#88F'

            'C4': (stack) ->
                turtle = stack.peek()
                turtle.ctx.strokeStyle = '#F4F'


            'F': (stack) ->
                turtle = stack.peek()
                turtle.forward 10

            'A': (stack) ->
                turtle = stack.peek()
                turtle.forward 10

            '[': (stack) ->
                currentTurtle = stack.peek()
                turtle = new Turtle(currentTurtle.historyKeeper)
                stack.push turtle
                turtle.ctx.save()

            ']': (stack) ->
                turtle = stack.pop()
                turtle.ctx.restore()

            '+': (stack) ->
                turtle = stack.peek()
                turtle.left 45

            '-': (stack) ->
                turtle = stack.peek()
                turtle.right 45
    'Test':
        axiom: 'F'
        rules:
            'F': 'FF'
        renderFunctions:
            'F': (stack) ->
                turtle = stack.peek()
                turtle.forward 10
            
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
                turtle = new Turtle()
                stack.push turtle
                turtle.ctx.save()
                turtle.left 45
            ']': (stack) ->
                turtle = stack.pop()
                turtle.ctx.restore()
                turtle.right 45
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

lsView = null
initialise = ->
    selectBox = document.getElementById 'systemselector'
    for key in Object.keys(lsystems)
        selectBox.options[selectBox.options.length] = new Option(key)

    currentSystem = Object.keys(lsystems)[0]
    lsView = new LSystemView(lsystems[currentSystem])

    $("#submitButton").click =>
            currentSystem = selectBox.value
            lsView = new LSystemView(lsystems[currentSystem])
            lsView.recompute()
            lsView.redraw()
            lsView.fitToCanvas()

    canvas = $("#canvas")[0]
    ctx = canvas.getContext '2d'

    transformState.xOffset = canvas.width / 2
    transformState.yOffset = canvas.height / 2

    zoomInButton = document.getElementById 'zoomIn'
    zoomInButton.onclick = (event) ->
        transformState.zoomIn 0.2
        ctx.scale transformState.zoomLevel, transformState.zoomLevel
        lsView.redraw()

    zoomOutButton = document.getElementById 'zoomOut'
    zoomOutButton.onclick = (event) ->
        transformState.zoomOut 0.2
        ctx.scale transformState.zoomLevel, transformState.zoomLevel
        lsView.redraw()


    $("#fitToCanvas").click ->
        lsView.fitToCanvas()

    $("#setZoom").click ->
        transformState.zoomLevel = parseFloat($("#zoom-factor").val())
        ctx.scale transformState.zoomLevel, transformState.zoomLevel
        lsView.redraw()

    #panLeftButton = document.getElementById 'panLeft'
    #panLeftButton.onclick = (event) ->
    #    transformState.xOffset -= 20
    #    ctx.translate transformState.xOffset, transformState.yOffset
    #    lsView.redraw()

    #panRightButton = document.getElementById 'panRight'
    #panRightButton.onclick = (event) ->
    #    transformState.xOffset += 20
    #    ctx.translate transformState.xOffset, transformState.yOffset
    #    lsView.redraw()

    #panDownButton = document.getElementById 'panDown'
    #panDownButton.onclick = (event) ->
    #    transformState.yOffset -= 20
    #    ctx.translate transformState.xOffset, transformState.yOffset
    #    lsView.redraw()

    #panUpButton = document.getElementById 'panUp'
    #panUpButton.onclick = (event) ->
    #    transformState.yOffset += 20
    #    ctx.translate transformState.xOffset, transformState.yOffset
    #    lsView.redraw()

    previousX = 0
    previousY = 0
    dragging = false
    moved = false

    canvas.onmousedown = (event) ->
        moved = false
        previousX = event.offsetX
        previousY = event.offsetY
        dragging = true

    canvas.onmouseup = (event) ->
        if moved
            lsView.redraw()
        dragging = false
        moved = false

    canvas.onmousemove = (event) ->
        if dragging
            moved = true
            transformState.xOffset += event.offsetX - previousX
            transformState.yOffset += event.offsetY - previousY

            previousX = event.offsetX
            previousY = event.offsetY


    lsView.recompute()
    lsView.redraw()
    lsView.fitToCanvas()
    
initialise()
