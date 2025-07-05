c = pipe_cor = pipe_tex = job = mat = res = ls = null

gr =
  dados_globais: null
  dados_materiais: []
  dados_instancias: null

arqs =
  nave: 'data/nave.txt2'
  asteroide: 'data/meteoro.ply'

nave = null

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


carrega_dados = () ->  
  res = c.resources_from_files(
    arqs.nave, arqs.asteroide,
    'data/tiro.png',
    'data/sprites/sp[1-4].png',
    'data/explosao1/explosao[0-6].png',
    'data/explosao2/explosao[0-7].png',
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

  nave = cria_nave( vec( 3,-2,0 ) ) # x:7 e y:5 da pra faze wrap around
  cria_asteroide( vec( -4,2,0 ) )

cria_novo = (inst) ->
  switch inst
    when 'asteroide'
      cria_asteroide(vec(-7, random_between(-5,5), 0))

    when 'coisa'
      cria_coisa(vec(-7, random_between(-5,5), 0))





cria_nave = (pos) ->
  inst = ls.instance( res.obj(arqs.nave), pipeline:pipe_cor )
  inst.set_class( 'nave' )

  inst.pos = pos
  inst.vel = vec( 0,0,0 )
  inst.ang = 0
  inst.frente = vec( 0,1,0 )
  inst.radius = 0.6


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
  coisa.radius = coisa.size * 0.7  


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

bateu = (inst1, inst2) -> 
  dx = inst1.pos.x - inst2.pos.x
  dy = inst1.pos.y - inst2.pos.y
  dz = inst1.pos.z - inst2.pos.z
  distancia = Math.sqrt(dx*dx + dy*dy + dz*dz)
        
  raio_colisao = inst1.radius + inst2.radius
        
  return distancia < raio_colisao

detectar_colisao = () ->
  tiros = ls.get_instances_by_class( 'tiro' )
  asteroides = ls.get_instances_by_class( 'asteroide' )
  inimigos = ls.get_instances_by_class( 'coisa' )


  for inimigo in inimigos
    if bateu(nave, inimigo)
      nave.remove() 
      inimigo.remove()
      cria_explosao(nave.pos)
      break
    
  for ast in asteroides
    if bateu(nave, ast)
      nave.remove() 
      ast.remove()
      cria_explosao(nave.pos)
      break

  for tiro in tiros
    for ast in asteroides
      if bateu(tiro, ast)
        tiro.remove() 
        ast.remove()
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
        inimigos_destruidos+=1

        break
  
renderiza = () ->
  processa_movimento()
  detectar_colisao()
  atualiza_uniforms()

  job.render_begin()
  job.render_instance_list( ls )
  job.render_end()
  job.gpu_send()

  c.animation_repeat renderiza, 10


ajuste = (pos) ->
# x:7 e y:5 da pra faze wrap around
  if pos.x > 7 || pos.x < -7
    pos.x *= -1
  
  if pos.y > 5 || pos.y < -5
    pos.y *= -1

  return pos


processa_movimento = () ->
  fator = 0.1

  asteroides = ls.get_instances_by_class( 'asteroide' )
  if (asteroides.length == 0)
    cria_novo('asteroide')
    cria_novo('asteroide')
    cria_novo('coisa')



  
  for ast in asteroides
    ast.pos = ajuste(ast.pos.add( ast.vel.mul_by_scalar(fator) ))


  tiros = ls.get_instances_by_class( 'tiro' )
  for tiro in tiros
    tiro.pos = tiro.pos.add( tiro.vel.mul_by_scalar(fator) )


  coisas = ls.get_instances_by_class( 'coisa' )


  for coisa in coisas
    coisa.pos = ajuste(coisa.pos.add( coisa.vel.mul_by_scalar(fator) ))


  ang_inc = 3
  y_inc = 0

  if teclas['ArrowUp'] >= 1
    y_inc = 1
  else if teclas['ArrowDown'] >= 1
    y_inc = -1
  
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


atualiza_uniforms = () ->

  for inst in ls.instances()
    u = inst.get_uniform_data()
    cl = inst.get_class()

    switch cl
      when 'nave'        
        u.model = TRS nave.pos, nave.ang,0,0,1, 0.3

      when 'asteroide'
        u.model = TRS inst.pos, inst.ang,1,1,1, inst.size
        inst.ang = inst.ang + 1

      when 'tiro'
        u.model = TRS inst.pos, inst.ang,0,0,1, 1.0
        inst.ang = inst.ang + 1

      when 'coisa', 'explosao'
        u.model = TRS inst.pos, 0,0,0,0, inst.size

  gr.dados_instancias.gpu_send()




main()