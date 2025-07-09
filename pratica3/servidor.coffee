http = require('http')
ws = require('ws')
WebSocketServer = ws.WebSocketServer


# protocolo - mensagens:
# assunto: ...
# conteudo: ...
#
# assuntos:
# - 'jogador entrou'
# - 'jogador saiu'
# - 'seu novo id'
# - 'estado atual de todos'
# - 'enviando meu estado'
#


# estado dos jogadores
jogadores = {}


envia_para_cada_um = (wss, msg) ->
  smsg = JSON.stringify(msg)

  wss.clients.forEach( (client) ->
    #console.log "--- cliente a ver:"
    #console.log client

    if not (msg.assunto == 'jogador entrou' and client.player_id == msg.conteudo.id)
      if client.readyState == WebSocket.OPEN
        console.log "-- enviando para cliente #{client.player_id}: #{smsg}"
        client.send( smsg )
  )

envia_ENTROU_de_todos_para_um = (wss, ws, player_id) ->
  console.log "Como o jogador #{player_id} entrou agora, vou avisar os que tinham entrado:"

  wss.clients.forEach( (client) ->
    console.log "- passando pelo cliente #{client.player_id}"

    if client.player_id != player_id and client.readyState == WebSocket.OPEN
      msg = {assunto:'jogador entrou', conteudo: { id: client.player_id }}
      smsg = JSON.stringify(msg)
      console.log " -- " + smsg

      ws.send( smsg )
  )

envia_ENTROU_para_cada_um = (wss, player_id) ->
  envia_para_cada_um(wss, {assunto:'jogador entrou', conteudo: { id: player_id} } )

envia_SAIU_para_cada_um = (wss, player_id) ->
  envia_para_cada_um(wss, {assunto:'jogador saiu', conteudo: { id: player_id} } )

envia_estado_atual_para_cada_um = (wss) ->
  #t = Date.now()
  #if t - last_msg_tempo < MSG_MIN_TEMPO then return
  #last_msg_tempo = t

  jogs = []
  for id of jogadores
    jogs.push { id:id, conteudo:jogadores[id].conteudo }

  envia_para_cada_um(wss, {assunto:'estado atual de todos', conteudo: { jogadores: jogs } })


servidor_inicializa = () ->
  server = http.createServer()
  wss = new WebSocketServer({ server })

  # Quando um cliente se conecta
  wss.on 'connection', (ws, req) ->

    # Atribui um ID único ao jogador
    player_id = Math.random().toString(36).substring(2, 6)
    jogadores[player_id] = { id: player_id, conteudo: '' }

    addr = req.socket.remoteAddress
    addr_porta = req.socket.remotePort
    addr_tipo = req.socket.remoteFamily
    console.log "Jogador conectado: id atribuído='#{player_id}', endereço remoto = '#{addr}', porta #{addr_porta}, tipo #{addr_tipo}"
    console.log req.headers

    nomes = Object.keys(jogadores)
    total = nomes.length    
    console.log "Total de jogadores agora: #{total} - [#{nomes}]"

    ws.player_id = player_id
    ws.send JSON.stringify({ assunto: 'seu novo id', conteudo: { id: player_id } })

    # avisa pra ele os que tinham entrado
    envia_ENTROU_de_todos_para_um( wss, ws, player_id )

    # avisa aos outros que ele entrou
    envia_ENTROU_para_cada_um( wss, player_id )


    # Recebe mensagens de algum cliente
    ws.on 'message', (data) ->
      player_id = ws.player_id
  
      addr = req.socket.remoteAddress
      addr_porta = req.socket.remotePort
      console.log "--- Recebido: '#{data}' de #{addr}, porta #{addr_porta}, id #{player_id}"

      dat = JSON.parse(data)
      if dat.assunto == 'enviando meu estado' and jogadores[player_id]
        jogadores[player_id] = { id: ws.player_id, conteudo:dat.conteudo }
        
        envia_estado_atual_para_cada_um( wss )


    ws.on 'error', console.error

    # Remove jogador ao desconectar
    ws.on 'close', ->
      delete jogadores[ws.player_id]
      console.log 'Jogador desconectado:', ws.player_id

      envia_SAIU_para_cada_um( wss, ws.player_id )


  # Inicia o servidor na porta 3000
  server.listen 3000, ->
    console.log 'Servidor rodando na porta 3000'

  
servidor_inicializa()
