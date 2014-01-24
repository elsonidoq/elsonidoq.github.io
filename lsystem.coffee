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
        n = 0
        start = 0
        canvas = document.getElementById("canvas")
        ctx = canvas.getContext '2d'
        ctx.strokeStyle = '#FFF'

        for i in [0..@axiom.length - 1]
            char = @axiom[start..i]
            if char not of @renderFunctions
                continue
            renderFunc = @renderFunctions[char]
            start = i+1
            renderFunc(@stack)
            n++
            #console.log n
            #console.log @stack.peek().historyKeeper.stateHistory.length
            #console.log '*'
            
        angle = @stack.peek().historyKeeper.currentAngle/Math.PI*180
        angle =  angle % 360
        console.log angle
        @stack.peek().historyKeeper.saveState('finished')

        ctx.setTransform(transformState.zoomLevel, 0, 0, transformState.zoomLevel, transformState.xOffset, transformState.yOffset)
        @
        

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

class TransformState
    zoomOut: (amount) ->
        @zoomLevel *= 0.9
        $("#zoom-factor").val @zoomLevel
    zoomIn: (amount) ->
        @zoomLevel /= 0.9
        $("#zoom-factor").val @zoomLevel
        
    xOffset: 0
    yOffset: 0
    zoomLevel: 1.0

transformState = new TransformState()

class LSystemView
    constructor: (systemSpec, startingPosition=null) ->
        @systemSpec = systemSpec
        @system = null
        @startingPosition = startingPosition or x:0, y:0
        @
    
    recompute: (hash = null) =>
        @system = new LSystem(@systemSpec)
        if hash?
            @system.axiom = hash

        numIterations = parseInt $("#numIterations").val()

        for num in [1..numIterations]
            @step()

    step: =>
        @system.axiom = @system.step()

    redraw: (clearCanvas = true) =>
        canvas = $("#canvas")[0]
        ctx = canvas.getContext '2d'

        topX = (-transformState.xOffset) / transformState.zoomLevel
        topY = (-transformState.yOffset) / transformState.zoomLevel
        width = canvas.width / transformState.zoomLevel
        height = canvas.height / transformState.zoomLevel

        ctx.setTransform(transformState.zoomLevel, 0, 0, transformState.zoomLevel, transformState.xOffset, transformState.yOffset)
        if clearCanvas
            ctx.fillStyle = 'black'
            ctx.fillRect topX, topY, width, height
        ctx.lineWidth = 2*Math.floor 1.0/transformState.zoomLevel
        #ctx.lineWidth = 0.1

        ctx.setTransform(transformState.zoomLevel, 0, 0, transformState.zoomLevel, transformState.xOffset, transformState.yOffset)
        ctx.translate(@startingPosition.x, @startingPosition.y)

        @system.stack.pop()
        @system.stack.push new Turtle(new HistoryKeeper())
        @system.render()

        #img = $('#canvas')[0].toDataURL("image/png")
        #uriContent = "data:application/octet-stream," + encodeURIComponent(img)
        #$("#download").attr 'href', img
        #$("#download").attr 'download', 'pepe.png'
    
    fitToCanvas: =>
        canvas = $("#canvas")[0]
        ctx = canvas.getContext '2d'

        boundingBox = @system.stack.pop().historyKeeper.boundingBox
        @system.stack.push new Turtle( new HistoryKeeper())

        boundingBoxWidth = boundingBox.maxX - boundingBox.minX
        boundingBoxHeight = boundingBox.maxY - boundingBox.minY
        zoomLevel = Math.min canvas.width/boundingBoxWidth, canvas.height/boundingBoxHeight
        zoomLevel = zoomLevel*0.9

        transformState.zoomLevel = zoomLevel
        transformState.xOffset = -boundingBox.minX*zoomLevel + (canvas.width - boundingBoxWidth*zoomLevel)/2
        transformState.yOffset = -boundingBox.minY*zoomLevel + (canvas.height - boundingBoxHeight*zoomLevel)/2

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
        
    cropAxiom: (rec) =>
        ruleNumber = 0
        historyKeeper = @system.stack.peek().historyKeeper
        anyIntersections = false
        startingAngle = null
        chunkStart = 0
        chunkEnd = 0
        views = []
        stringPosition = 0
        while ruleNumber < @system.axiom.length
            ruleName = @system.axiom[stringPosition]

            ruleState = historyKeeper.stateHistory[ruleNumber]
            nextRuleState = historyKeeper.stateHistory[ruleNumber+1]
            charInRec = inRectangle(rec, ruleState.position) and inRectangle(rec, nextRuleState.position)
            

            if charInRec and ruleNumber < @system.axiom.length - 1
                if not anyIntersections
                    startingAngle = ruleState.angle / Math.PI * 180
                    startingAngle = startingAngle % 360
                    startingAngle = Math.round(startingAngle)
                    startingPosition = ruleState.position
                    chunkStart = stringPosition
                    anyIntersections = true

            else if anyIntersections# and views.length <= 2
                chunkEnd = stringPosition
                if charInRec
                    chunkEnd+= ruleName.length

                o = expandChunk @system.axiom, chunkStart, chunkEnd, ruleNumber
                chunk = o.chunk
                chunkStart = o.chunkStart
                chunkEnd = o.chunkEnd
                ruleNumber = o.ruleNumber
                stringPosition = chunkEnd

                newSystemSpec = _.clone @systemSpec
                #debugger
                chunk = @getChunkAxiom chunk, startingAngle
                newSystemSpec.axiom = chunk

                view = new LSystemView(newSystemSpec, startingPosition=startingPosition)
                view.system = new LSystem(newSystemSpec)
                view.system.axiom = chunk
                views.push view

                anyIntersections = false


            ruleNumber++
            stringPosition += ruleName.length



        res = new MultiLSystemView views
        return res
        
            
class MultiLSystemView extends LSystemView
    constructor: (lsViews) ->
        @lsViews = lsViews
        for e in lsViews
            console.log e.system.axiom
            console.log e.startingPosition

    redraw: =>
        canvas = $("#canvas")[0]
        ctx = canvas.getContext '2d'
        for i in [0..@lsViews.length-1]
            clearCanvas = i == 0
            @lsViews[i].redraw clearCanvas
            
    step: =>
        for e in @lsViews
            e.step()

    recompute: =>
        for e in @lsViews
            e.recompute()

    fitToCanvas: =>
        canvas = $("#canvas")[0]
        ctx = canvas.getContext '2d'

        boundingBox = @lsViews[0].system.stack.peek().historyKeeper.boundingBox
        boundingBox = translateBoundingBox boundingBox, @lsViews[0].startingPosition
        for e in @lsViews
            newBoundingBox = e.system.stack.pop().historyKeeper.boundingBox
            newBoundingBox = translateBoundingBox newBoundingBox, e.startingPosition
            boundingBox = mergeBoundingBoxes boundingBox, newBoundingBox
            e.system.stack.push new Turtle( new HistoryKeeper())

        boundingBoxWidth = boundingBox.maxX - boundingBox.minX
        boundingBoxHeight = boundingBox.maxY - boundingBox.minY
        zoomLevel = Math.min canvas.width/boundingBoxWidth, canvas.height/boundingBoxHeight
        zoomLevel = zoomLevel*0.9

        transformState.zoomLevel = zoomLevel
        transformState.xOffset = -boundingBox.minX*zoomLevel + (canvas.width - boundingBoxWidth*zoomLevel)/2
        transformState.yOffset = -boundingBox.minY*zoomLevel + (canvas.height - boundingBoxHeight*zoomLevel)/2

        $("#zoom-factor").val zoomLevel

        @redraw()


    cropAxiom: (rec) =>
        newSystems = []
        debugger
        for e in @lsViews
            newSystems = newSystems.concat e.cropAxiom(rec)
        return new MultiLSystemView newSystems

        

translateBoundingBox = (boundingBox, startingPosition) ->
    boundingBox = _.clone boundingBox
    boundingBox.minX += startingPosition.x
    boundingBox.maxX += startingPosition.x
    boundingBox.minY += startingPosition.y
    boundingBox.maxY += startingPosition.y
    return boundingBox
            
        
inRectangle= (rec, point) ->
    return point.x >= rec.x0 and point.x <= rec.x1 and point.y >= rec.y0 and point.y <= rec.y1

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

lsystems =
    'Sandbox Mandala':
        #axiom: '[--A+A][+A--A]-A++A-C1AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-C2AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-C3AA[+A--A]-A++A+A+A++[--A+A][+A--A]-A++A-C4AA[+A--A]-A++A+A+A--C1'
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
                turtle = new Turtle(historyKeeper)
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
                turtle = new Turtle(historyKeeper)
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
                turtle = new Turtle(historyKeeper)
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

    $("#step").click =>
            lsView.step()
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

    rec = x0: 0, y0: 0, x1: 0, y1: 0

    clickdown = false

    canvas.onmousedown = (event) ->
        moved = false
        console.log event.offsetX
        console.log event.offsetY
        rec.x0 = (event.offsetX - transformState.xOffset)/transformState.zoomLevel
        rec.y0 = (event.offsetY - transformState.yOffset)/transformState.zoomLevel
        clickdown = true

    canvas.onmouseup = (event) ->
        rec.x1 = (event.offsetX - transformState.xOffset)/transformState.zoomLevel
        rec.y1 = (event.offsetY - transformState.yOffset)/transformState.zoomLevel
        if rec.y1 < rec.y0
            tmp = rec.y1
            rec.y1 = rec.y0
            rec.y0 = tmp

        if rec.x1 < rec.x0
            tmp = rec.x1
            rec.x1 = rec.x0
            rec.x0 = tmp

        #rec = {x0: -12.124717002140441, y0: -35.837659103671726, x1: 11.695523479940773, y1: -13.841491090939073}

        width = rec.x1 - rec.x0
        height = rec.y1 - rec.y0
        canvas = document.getElementById("canvas")
        ctx = canvas.getContext '2d'

        ctx.fillStyle="#00FFFF"
        ctx.fillRect rec.x0, rec.y0, width, height
        #console.log rec
        #return
        clickdown = false
        if Math.abs(rec.x0-rec.x1)*Math.abs(rec.y1-rec.y0) >= 5
            lsView = lsView.cropAxiom rec
            lsView.redraw()
            lsView.fitToCanvas()


    lsView.recompute()
    lsView.redraw()
    lsView.fitToCanvas()
    
initialise()
