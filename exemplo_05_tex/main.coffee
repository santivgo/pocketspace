c = pipe = job = mat = null


objs =
  quad: null

shader_groups =
  para_matriz: null
  para_tex: null

ang = 0



main = () =>
  c = await wgpu_context_new canvas:'tela', transparent:true
  c.vertex_format 'xy', 'rgba', 'uv'

  job = c.job()
  mat = use_mat4x4_format()

  cria_objs()
  await cria_shader_groups()
  await cria_pipeline()
  
  renderiza()



cria_objs = () ->
  verts = [
    0,0, 1,1,0,1, 0,1,
    1,0, 0,1,1,1, 1,1,
    1,1, 1,0,1,1, 1,0,
    0,1, 1,1,1,1, 0,0
  ]
  indices = [0,1,2, 2,3,0]
  objs.quad = c.obj_from_data( verts, indices )


cria_shader_groups = () ->
  t = await c.tex_from_file 'data/textura.png'
  ts = c.tex_sampler 'linear'

  shader_groups.para_tex = c.shader_data_group()
  shader_groups.para_tex.binding(0).set_tex( t )
  shader_groups.para_tex.binding(1).set_tex_sampler( ts )

  #--------

  u = c.uniform()
  u.begin()
  u.mat4x4('matriz')
  u.end()

  shader_groups.para_matriz = c.shader_data_group()
  shader_groups.para_matriz.binding(0).set_uniform( u )


cria_pipeline = () ->
  pipe = c.pipeline()
  pipe.begin( 'triangles' )

  await pipe.shader_from_file 'shader.wgsl'
  pipe.expect_group(0).binding(0).uniform()

  pipe.expect_group(1).binding(0).tex()
  pipe.expect_group(1).binding(1).tex_sampler()

  pipe.end()



renderiza = () ->
  R = mat.rotate ang, 0,0,1
  T1 = mat.translate -0.5,-0.5,0
  T2 = mat.translate 0.5,0.5,0
  ang += 0.5
  
  u = shader_groups.para_matriz.binding(0).get_uniform()
  u.matriz = mat_mul T1, T2, R, T1
  u.gpu_send()
  
  job.render_begin()
  job.render_use_group 0, shader_groups.para_matriz
  job.render_use_group 1, shader_groups.para_tex
  job.render_obj( pipe, objs.quad )
  job.render_end()
  job.gpu_send()

  c.animation_repeat renderiza, 10


main()