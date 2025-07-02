
main = () =>
  c = await wgpu_context_new canvas:'tela', debug:true  
  c.vertex_format 'xy', 'rgba'
  
  tri = c.obj()
  tri.begin()
  tri.vert(1,1,  1,0,0,1)
  tri.vert(0,0,  0,1,0,1)
  tri.vert(1,0,  0,0,1,1)
  tri.end()

  p = c.pipeline()
  p.begin( 'triangles' )
  await p.shader_from_file 'shader.wgsl'
  p.end()

  j = c.job()
  j.render_begin()
  j.render_obj( p, tri )
  j.render_end()
  j.gpu_send()

main()
