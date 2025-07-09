c = pipe_cor = pipe_tex = job = mat = res = ls = null
propulsao = null
jogo_acabou = false



gr =
  dados_globais: null
  dados_materiais: []
  dados_instancias: null

arqs =
  nave: 'data/nave.ply'
  asteroide: 'data/meteoro.ply'
  coracao: 'data/coracao.ply'


nave = null
rastro_propulsao = null  # Variável para manter referência ao rastro
hp_nave = 3
nivel_atual = 1
multiplicador_lv = 1.2

coracoes = []

obj_quad = null

teclas = {}

asteroides_destruidos = 0
inimigos_destruidos = 0 


main = () =>
  c = await wgpu_context_new canvas:'tela', debug:true, transparent:true

  c.frame_buffer_format 'color', 'depth'
  c.vertex_format 'xyz', 'rgba', 'uv'
  mat = c.use_mat4x4_format()


  await carrega_dados()
  prepara_shader_data_groups()
  prepara_pipelines()
  prepara_instancias()
  prepara_teclado_eventos()
  toca_som('trilha')
  

  
  job = c.job()
  renderiza()

  multiplayer_connect_to_server( '10.80.60.124' )


carrega_dados = () ->  
  res = c.resources_from_files(
    arqs.nave, arqs.asteroide, arqs.coracao
    'data/tiro.png',
    'data/coracao.png',
    'data/sprites/sp[1-4].png',
    'data/explosao1/explosao[0-6].png',
    'data/explosao2/explosao[0-7].png',
    'data/propulsao/flicker/[1-6].png',
    'data/rastro[1-2].png',
    'shader_cor.wgsl', 'shader_tex.wgsl'
  )
  await res.load_all()


prepara_shader_data_groups = () ->
  gr.dados_globais = c.shader_data_group_with_uniform()
  u = gr.dados_globais.binding(0).get_uniform()
  u.begin()
  u.mat4x4('view')
  u.mat4x4('proj')
  u.end()

  u.proj = mat.perspective(50, c.canvas.width/c.canvas.height, 0.1, 10)
  u.view = mat.look_at( vec(0,0,8), vec(0,0,0), vec(0,1,0) )
  u.gpu_send()

  gr.dados_materiais = res.materials_from_tex_list()

  gr.dados_instancias = c.shader_data_group_with_uniform_list(300)
  u = gr.dados_instancias.binding(0).get_uniform_list()
  u.begin()
  u.mat4x4('model')
  u.end()


atualiza_score = () ->
  try
    scoreElemento = document.getElementById('score')
    scoreElemento.textContent = (asteroides_destruidos + inimigos_destruidos).toString()

loop_propulsao = (inst) ->
  inst.start_animation_from_materials(
    'data/propulsao/flicker/[1-6].png',
    gr.dados_materiais,
    on_animation_end: loop_propulsao
  )

controle_nivel = () ->
  scoreElemento = document.getElementById('score')
  nivelElemento = document.getElementById('level')

  score = parseInt(scoreElemento.textContent)

  nivel_atual += 1
  nivelElemento.textContent = ( nivel_atual ).toString() 

  if Math.random() < 0.3
    cria_coracao_power()


prepara_pipelines = () ->
  pipe_cor = c.pipeline()
  pipe_cor.begin( 'triangles' )
  pipe_cor.shader_from_src( res.text('shader_cor.wgsl') )
  pipe_cor.depth_test( true )
  pipe_cor.expect_group(0).binding(0).uniform()
  pipe_cor.expect_group(2).binding(0).uniform_list()
  pipe_cor.end()

  pipe_tex = c.pipeline()
  pipe_tex.begin( 'triangles' )
  pipe_tex.shader_from_src( res.text('shader_tex.wgsl') )
  pipe_tex.depth_test( true )
  pipe_tex.depth_write( false )

  pipe_tex.expect_group(0).binding(0).uniform()
  pipe_tex.expect_group(1).binding(0).tex()
  pipe_tex.expect_group(1).binding(1).tex_sampler()
  pipe_tex.expect_group(2).binding(0).uniform_list()
  pipe_tex.end()


prepara_instancias = () ->
  vdata = [
    -0.5,-0.5,0.0, 1.0,0.0,0.0,1.0, 0.0,1.0,
    +0.5,-0.5,0.0, 0.0,1.0,0.0,1.0, 1.0,1.0,
    +0.5,+0.5,0.0, 0.0,0.0,1.0,1.0, 1.0,0.0,
    -0.5,+0.5,0.0, 1.0,1.0,0.0,1.0, 0.0,0.0 ]
  indices = [0,1,2, 2,3,0]
  obj_quad = c.obj_from_data( vdata, indices )


  ls = c.instance_list()
  ls.use_groups(
    global_index:   0, global_group: gr.dados_globais,
    material_index: 1,
    instance_index: 2, instance_group: gr.dados_instancias
  )

  cria_coracoes()
  nave = cria_nave( vec( 3,-2,0 ) ) # x:7 e y:5 da pra faze wrap around
  cria_asteroide( vec(-7, random_between(-5,5), 0) )
  propulsao = ls.instance(obj_quad, pipeline: pipe_tex)
  propulsao.set_class('propulsao')
  propulsao.size = 1
  propulsao.visivel = false
  propulsao.start_animation_from_materials( 'data/propulsao/flicker/[1-6].png',gr.dados_materiais,
  on_animation_end: (inst) => 
    inst.start_animation_from_materials(
      'data/propulsao/flicker/[1-6].png',
      gr.dados_materiais,
      on_animation_end: loop_propulsao
    )
  )
cria_novo = (inst) ->
  switch inst
    when 'asteroide'
      cria_asteroide(vec(-7, random_between(-5,5), 0))
      break

    when 'coisa'
      cria_coisa(vec(-7, random_between(-5,5), 0))
      break


cria_coracoes = () ->
  for coracao in coracoes
    coracao.remove()
  coracoes.length = 0

  if hp_nave > 9
    hp_nave = 9

  mt_coracao = gr.dados_materiais.get_by_url('data/coracao.png')

  for i in [0...hp_nave]
    coracao = ls.instance(obj_quad, pipeline: pipe_tex, material: mt_coracao)

    coracao.set_class('coracao')
    coracao.pos = vec(-5.5 + i * 0.5, 3, 0)
    coracao.size = 0.4
    coracoes.push(coracao)


cria_nave = (pos) ->
  inst = ls.instance( res.obj(arqs.nave), pipeline:pipe_cor )
  inst.set_class( 'nave' )

  inst.pos = pos
  inst.vel = vec( 0,0,0 )
  inst.ang = 0
  inst.frente = vec( 0,1,0 )
  inst.radius = 1


  return inst


cria_asteroide = (pos, size = 0.17) ->
  min_pos = vec( -3,-3, 0 )
  max_pos = vec( +3,+3, 0 )

  max_vel = vec( 1,1, 0 )
  min_vel = vec( -1,-1, 0 )



  if not pos?
    pos = vec_random( min_pos, max_pos )

  ast = ls.instance( res.obj(arqs.asteroide), pipeline:pipe_cor )
  ast.set_class( 'asteroide' )

  ast.pos = pos
  ast.vel = vec_random(min_vel, max_vel).mul_by_scalar(0.2) 
  ast.ang = random(90)
  ast.size = size
  ast.radius = ast.size * 1.5

  return ast


cria_coracao_power = (pos, size = 0.1) ->
  min_pos = vec( 7,-3, 0 )
  max_pos = vec( 7,+3, 0 )

  max_vel = vec( 1,1, 0 )
  min_vel = vec( -1,-1, 0 )



  if not pos?
    pos = vec_random( min_pos, max_pos )

  ast = ls.instance( res.obj(arqs.coracao), pipeline:pipe_cor )
  ast.set_class( 'coracao_power' )

  ast.pos = pos
  ast.vel = vec_random(min_vel, max_vel).mul_by_scalar(0.2) 
  ast.ang = random(90)
  ast.size = size
  ast.radius = ast.size * 1.5

  return ast



cria_tiro = (nave) ->
  inst = ls.instance( obj_quad, pipeline:pipe_tex, material:gr.dados_materiais[0] )
  inst.set_class( 'tiro' )

  inst.pos = nave.pos.add(nave.frente.mul_by_scalar(0.8))
  inst.radius = 0.1

  inst.vel = nave.frente.mul_by_scalar(1)
  inst.ang = 0

  return inst


cria_explosao = (pos) ->
  inst = ls.instance( obj_quad, pipeline:pipe_tex )
  inst.set_class( 'explosao' )

  inst.pos = pos
  inst.size = 2.0
  inst.start_animation_from_materials(
    'data/explosao1/explosao[0-6].png',
    gr.dados_materiais,
    on_animation_end: (inst) ->
      inst.remove()
  )



cria_coisa = (pos) ->
  min_pos = vec( -3,-3, 0 )
  max_pos = vec( +3,+3, 0 )



  max_vel = vec( 1,1, 0 )
  min_vel = vec( -1,-1, 0 )

  if not pos?
    pos = vec_random( min_pos, max_pos )

  url = res.get_url_group_random_item('data/sprites/sp[1-4].png')
  mt = gr.dados_materiais.get_by_url(url) 

  coisa = ls.instance( obj_quad, pipeline:pipe_tex, material:mt )
  coisa.set_class( 'coisa' )

  coisa.pos = pos
  coisa.vel = vec_random(min_vel, max_vel).mul_by_scalar(0.1) 

  coisa.size = 1.0
  coisa.radius = coisa.size * 0.3
  coisa.forca_perseguicao = 0.05  # Força de perseguição
  coisa.velocidade_maxima = 0.8   # Velocidade máxima

  return coisa


toca_som = (inst) ->
  audioContext = new AudioContext();
  source = audioContext.createBufferSource();
  gainNode = audioContext.createGain();
  analyser = audioContext.createAnalyser();
  
  switch inst
    when 'tiro'
      response = await fetch('data/sounds/shoot.mp3');
      gainNode.gain.value = 0.1
    when 'trilha'
      response = await fetch('data/sounds/trilha.mp3');
      gainNode.gain.value = 0.06
      source.loop = true;
    when 'colisao'
      response = await fetch('data/sounds/boom.wav');
      gainNode.gain.value = 0.06



  arrayBuffer = await response.arrayBuffer();
  audioBuffer = await audioContext.decodeAudioData(arrayBuffer);



  source.buffer = audioBuffer;


  source.connect(gainNode)
  gainNode.connect(analyser);
  analyser.connect(audioContext.destination);

  source.start();


prepara_teclado_eventos = () ->
  document.addEventListener 'keydown', on_keydown
  document.addEventListener 'keyup', on_keyup

random_between = (min, max) ->
  Math.random() * (max - min) + min

random_or = (another, other) ->
  Math.random() < 0.5 ? another : other



on_keydown = (event) ->
  if event.key == ' ' then event.preventDefault()

  if not teclas[ event.key ]?
    teclas[ event.key ] = 1
  else
    teclas[ event.key ]++

on_keyup = (event) ->
  teclas[ event.key ] = 0

apertando_tecla = (key) ->
  return teclas[ key ] >= 1

apertou_tecla = (key) ->
  apertou = teclas[ key ] == 1
  if apertou
    teclas[ key ] = 2

piscar_nave = () ->
  vezes = 0
  intervalo = setInterval( ->
    nave.visivel = not nave.visivel
    vezes += 1
    if vezes >= 6  # 6 trocas = 3 piscadas
      clearInterval(intervalo)
      nave.visivel = true  # garante que termina visível
  , 50)  

bateu = (inst1, inst2) -> 
  dx = inst1.pos.x - inst2.pos.x
  dy = inst1.pos.y - inst2.pos.y
  dz = inst1.pos.z - inst2.pos.z
  distancia = Math.sqrt(dx*dx + dy*dy + dz*dz)
        
  raio_colisao = inst1.radius + inst2.radius
        
  return distancia < raio_colisao



nave_destruida = () ->
  hp_nave = hp_nave - 1
  piscar_nave()

  if coracoes.length > 0
    ultimo = coracoes.pop()
    ultimo.remove()

  if hp_nave == 0
    nave.remove() 
    cria_explosao(nave.pos) 
    jogo_acabou = true

    document.getElementById('btn-reiniciar').style.display = 'block'

    document.getElementById('ast-destruidos').textContent = asteroides_destruidos
    document.getElementById('inim-destruidos').textContent = inimigos_destruidos
    document.getElementById('resultados').style.display = 'block'

    return true

  return false

detectar_colisao = () ->
  tiros = ls.get_instances_by_class( 'tiro' )
  asteroides = ls.get_instances_by_class( 'asteroide' )
  inimigos = ls.get_instances_by_class( 'coisa' )
  coracoes_power = ls.get_instances_by_class( 'coracao_power' )

  for coracao in coracoes_power
    if bateu(nave, coracao)
      hp_nave += 1
      coracao.remove()

      cria_coracoes()

  for inimigo in inimigos
    if bateu(nave, inimigo)
      inimigo.remove()
      toca_som('colisao')

      if nave_destruida() 
        if rastro_propulsao?
          rastro_propulsao.deve_remover = true
          rastro_propulsao = null
        break

  for ast in asteroides
    if bateu(nave, ast)
      ast.remove()
      toca_som('colisao')

      if nave_destruida()
        # Marca o rastro para remoção quando a nave é destruída
        if rastro_propulsao?
          rastro_propulsao.deve_remover = true
          rastro_propulsao = null

        break

  for tiro in tiros
    for ast in asteroides
      if bateu(tiro, ast)
        tiro.remove()
        ast.remove()
        toca_som('colisao')
        cria_explosao(ast.pos)
        asteroides_destruidos+=1

        if(ast.size > 0.1)
          cria_asteroide(ast.pos, random_between(0.06, ast.size/1.3))
          cria_asteroide(ast.pos, random_between(0.06, ast.size/1.3))
          break

    for inimigo in inimigos
      if bateu(tiro, inimigo)
        tiro.remove()
        inimigo.remove()
        cria_explosao(inimigo.pos)
        toca_som('colisao')
        inimigos_destruidos+=1
        break
  
renderiza = () ->
  if not jogo_acabou
    processa_movimento()
    detectar_colisao()
  atualiza_uniforms()

  job.render_begin()
  job.render_instance_list( ls )
  job.render_end()
  job.gpu_send()
  atualiza_score()


  c.animation_repeat renderiza, 10


ajuste = (pos) ->
# x:7 e y:5 da pra faze wrap around
  if pos.x > 7 || pos.x < -7
    pos.x *= -1
  
  if pos.y > 5 || pos.y < -5
    pos.y *= -1

  return pos

calcular_direcao_para_nave = (inimigo_pos, nave_pos) ->

  dx = nave_pos.x - inimigo_pos.x
  dy = nave_pos.y - inimigo_pos.y
  dz = nave_pos.z - inimigo_pos.z


  # Calcula a distância
  distancia = Math.sqrt(dx*dx + dy*dy + dz*dz)

  if distancia == 0
    return vec(0, 0, 0)

  # Normaliza o vetor (direção unitária)
  return vec(dx/distancia, dy/distancia, dz/distancia)

spawner_niveis = () ->
  cria_novo('asteroide')
  if nivel_atual == 2
    cria_novo('asteroide')
    cria_novo('coisa')
  if nivel_atual > 2
    cria_novo('coisa')
    cria_novo('coisa')
  if nivel_atual > 4
    cria_novo('coisa')
    for nivel in [0..nivel_atual]
      if nivel % 2 == 0
        cria_novo('coisa')
    cria_novo('coisa')
    cria_novo('asteroide')

processa_movimento = () ->
  fator = 0.1

  asteroides = ls.get_instances_by_class( 'asteroide' )
  coracoes_powerup = ls.get_instances_by_class( 'coracao_power' )

  if (asteroides.length == 0 || asteroides_destruidos + inimigos_destruidos > nivel_atual * 5)
    controle_nivel()
    spawner_niveis()
  
  for ast in asteroides
    ast.pos = ajuste(ast.pos.add( ast.vel.mul_by_scalar(fator * multiplicador_lv) ))

  for coracao_p in coracoes_powerup
    coracao_p.pos = ajuste(coracao_p.pos.add( coracao_p.vel.mul_by_scalar(fator) ))

  tiros = ls.get_instances_by_class( 'tiro' )
  for tiro in tiros
    tiro.pos = tiro.pos.add( tiro.vel.mul_by_scalar(fator) )


  coisas = ls.get_instances_by_class( 'coisa' )


  for coisa in coisas
    if nave?
      direcao = calcular_direcao_para_nave(coisa.pos, nave.pos)
    
      forca = direcao.mul_by_scalar(coisa.forca_perseguicao * multiplicador_lv)
      coisa.vel = coisa.vel.add(forca)
      
      vel_magnitude = Math.sqrt(coisa.vel.x*coisa.vel.x + coisa.vel.y*coisa.vel.y)
      if vel_magnitude > coisa.velocidade_maxima
        coisa.vel = coisa.vel.mul_by_scalar(coisa.velocidade_maxima / vel_magnitude)
  
    coisa.pos = ajuste(coisa.pos.add( coisa.vel.mul_by_scalar(0.3) ))
    coisa.vel = coisa.vel.mul_by_scalar(0.2)



  ang_inc = 4
  y_inc = 0

  if teclas['ArrowUp'] >= 1
    y_inc = 1
  else if teclas['ArrowDown'] >= 1
    y_inc = -1

  
  if y_inc == 1  # Se está acelerando para frente
    propulsao.visivel = true
    propulsao.pos = nave.pos.add(nave.frente.mul_by_scalar(-0.8))
    propulsao.ang = nave.ang + Math.PI  # Rotaciona 180 graus para ficar atrás da nave

  else
    propulsao.visivel = false



  
  if y_inc == -1
    ang_inc = -ang_inc


  if apertando_tecla( 'ArrowLeft' ) 
    nave.ang += ang_inc
  else if apertando_tecla( 'ArrowRight' )
    nave.ang -= ang_inc

  if apertou_tecla( ' ' ) 
    cria_tiro( nave )
    toca_som( 'tiro' )

  
  if apertou_tecla( 'a' )
    cria_asteroide()
    

  if apertou_tecla( 'c' )
    cria_coisa()
  
  if apertou_tecla('e')
    cria_explosao(vec_random())


  v = vec(0,1,0)
  R = mat.rotate nave.ang
  nave.frente = mat_mul R, v

  if y_inc != 0
    nave.vel = nave.vel.add( nave.frente.mul_by_scalar(fator*y_inc) )

  nave.pos = ajuste(nave.pos.add( nave.vel.mul_by_scalar(fator) ))


  nave.vel = nave.vel.mul_by_scalar( 0.95 )


TRS = (pos, ang,rx,ry,rz, scale_factor) ->
  S = mat.scale scale_factor
  R = mat.rotate(ang, rx,ry,rz) 
  T = mat.translate pos
  return mat.mul T, R, S

multiplayer_info =
  ativado: true
  porta: ':3000'
  socket: null
  meu_id: ''
  jogadores: {}
  inst_dos_jogadores: {}


multiplayer_connect_to_server = (servidor) ->
  if not multiplayer_info.ativado then return

  url = 'ws://' + servidor + multiplayer_info.porta  
  multiplayer_info.socket = new WebSocket(url)
  
  multiplayer_info.socket.onopen = () ->
    console.log '--- Conectado ao servidor'

  multiplayer_info.socket.onclose = ->
    console.log '--- Desconectado do servidor'

  multiplayer_info.socket.onmessage = (event) ->
    #console.log "-- Recebeu msg: '#{event.data}'"

    msg_recebida = JSON.parse(event.data)

    switch msg_recebida.assunto

      when 'seu novo id'
        meu_novo_id = msg_recebida.conteudo.id
        console.log "--- ID atribuído pelo servidor: #{meu_novo_id}"

        multiplayer_info.meu_id = meu_novo_id
        document.title = "Jogador: " + meu_novo_id


      when 'jogador entrou'
        jogador_id = msg_recebida.conteudo.id

        console.log "--- Jogador entrou - id: #{jogador_id}"

        # recebemos o aviso que entrou um jogador.
        # vamos criar uma instância pra ele e
        # aguardar a atualização do estado para
        # determinar a posição da instância, etc.
        #
        inst = ls.instance( res.obj(arqs.nave), pipeline:pipe_cor )
        multiplayer_info.inst_dos_jogadores[ jogador_id ] = inst

        inst.set_class( 'multiplayer-nave' )
        inst.pos = vec(0,0,0)
        inst.ang = 0


      when 'jogador saiu'
        jogador_id = msg_recebida.conteudo.id
        console.log "--- Jogador saiu - id: #{jogador_id}"

        # um jogador saiu. vamos remover a instância dele.
        multiplayer_info.inst_dos_jogadores[ jogador_id ].remove()
        delete multiplayer_info.inst_dos_jogadores[jogador_id]


      when 'estado atual de todos'
        multiplayer_info.jogadores = msg_recebida.conteudo.jogadores

        # recebemos o estado geral da partida,
        # contendo os dados de todos os jogadores.
        #
        for jogador in multiplayer_info.jogadores

          # recebemos até o nosso próprio dado,
          # mas vamos ignorar ele.
          if jogador.id == multiplayer_info.meu_id
            continue

          conteudo = jogador.conteudo
          inst = multiplayer_info.inst_dos_jogadores[ jogador.id ]
          inst.pos = vec_from_array( conteudo.pos )
          inst.ang = conteudo.ang


multiplayer_send_to_server = () ->
  if not multiplayer_info.ativado then return
     
  if multiplayer_info.socket?.readyState == WebSocket.OPEN
    
    # envia meus dados para o servidor. o que eu enviar
    # é o que eu recebo dos outros tb.
    #
    msg = JSON.stringify(
      assunto: 'enviando meu estado'
      conteudo:
        pos: vec_to_array( nave.pos )
        ang: nave.ang
    )
    multiplayer_info.socket.send msg



atualiza_uniforms = () ->

  for inst in ls.instances()
    continue unless inst? and inst.get_uniform_data?
    u = inst.get_uniform_data()
    cl = inst.get_class()
    multiplayer_send_to_server()

    switch cl
      when 'multiplayer-nave'
        u.model = TRS inst.pos, inst.ang,0,0,1, 0.3

      when 'coracao'
        u.model = TRS inst.pos, 0,0,0,0, inst.size

      when 'nave'        
        if inst.visivel == false
          u.model = mat.scale(0)
        else
          u.model = TRS nave.pos, nave.ang,0,0,1, 0.3

      when 'asteroide', 'coracao_power'
        u.model = TRS inst.pos, inst.ang,1,1,1, inst.size
        inst.ang = inst.ang + 1

      when 'tiro'
        u.model = TRS inst.pos, inst.ang,0,0,1, 1.0
        inst.ang = inst.ang + 1
      
      when 'propulsao'
        if inst.visivel == false
          u.model = mat.scale(0)
        else
          u.model = TRS inst.pos, inst.ang, 0,0,1, inst.size

      when 'coisa', 'explosao'
        u.model = TRS inst.pos, 0,0,0,0, inst.size

  gr.dados_instancias.gpu_send()



main()

window.reiniciar = () =>
  location.reload()