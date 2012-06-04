events= require("events")
fs = require('fs')
path = require('path')


environment = process.env['NODE_ENV'] || 'development'

class Tail extends events.EventEmitter

  readBlock:()=>
    if @queue.length >= 1
      block=@queue[0]
      if block.end > block.start
        stream = fs.createReadStream(@filename, {start:block.start, end:block.end-1, encoding:"utf-8"})
        stream.on 'error',(error) =>
          console.log("Tail error:#{error}")
          @emit('error', error)
        stream.on 'end',=>
          @queue.shift()
          @internalDispatcher.emit("next") if @queue.length >= 1
        stream.on 'data', (data) =>
          @buffer += data
          parts = @buffer.split(@separator)
          @buffer = parts.pop()
          @emit("line", chunk) for chunk in parts

  constructor:(@filename, @separator='\n') ->    
    @buffer = ''
    @internalDispatcher = new events.EventEmitter()
    @queue = []
             
    @internalDispatcher.on 'next',=>
      @readBlock()
    if path.existsSync @filename
      @prev = fs.statSync(@filename)
    else
      @prev = new fs.Stats()

#    fs.watchFile @filename, (curr, prev) =>
#      if curr.size > prev.size
#        @queue.push({start:prev.size, end:curr.size})  
#        @internalDispatcher.emit("next") if @queue.length is 1
    fs.watch @filename, (event, fname) =>
      if event is 'change'
        if path.existsSync @filename
          curr = fs.statSync(@filename)
          if curr.size > @prev.size
            @queue.push({start:@prev.size, end:curr.size})  
            @internalDispatcher.emit("next") if @queue.length is 1
          @prev = curr
        else if event is 'rename'
          @prev.size = 0
      
  unwatch:->
    fs.unwatchFile @filename
    @queue = []
        
exports.Tail = Tail
