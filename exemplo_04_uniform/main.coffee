
main = () =>
  c = await wgpu_context_new canvas:'tela'
  c.vertex_format 'xy', 'rgba'
  mat = c.use_mat3x3_format()


  tri = c.obj()  
  tri.begin()
  tri.vert(0.0,0.0, 1,0,0,1)
  tri.vert(0.5,0.0, 0,1,0,1)
  tri.vert(0.5,0.5, 0,0,1,1)
  tri.end()
  
  p = c.pipeline()
  p.begin( 'triangles' )
  await p.shader_from_file 'shader.wgsl'
  p.expect_group(0).binding(0).uniform()
  p.end()


  g = c.shader_data_group()
  g.binding(0).uniform()

  u = g.binding(0).get_uniform()
  u.begin()
  u.mat3x3('matriz')
  u.end()

  S = mat.scale 2,1
  R = mat.rotate 90
  u.matriz = mat.mul S, R
  u.gpu_send()


  j = c.job()
  j.render_begin()
  j.render_use_group 0, g
  j.render_obj( p, tri )
  j.render_end()
  j.gpu_send()


main()