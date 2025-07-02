
main = () =>
  c = await wgpu_context_new canvas:'tela', debug:true
  c.vertex_format 'xy', 'rgba'


  vdata = [
    0.0,0.0, 1.0,0.0,0.0,1.0,
    0.5,0.0, 0.0,1.0,0.0,1.0,
    0.5,0.5, 0.0,0.0,1.0,1.0,
    0.0,0.5, 1.0,1.0,0.0,1.0 ]

  indices = [0,1,2, 2,3,0]
  
  obj = c.obj_from_data( vdata, indices )


  p = c.pipeline()
  p.begin( 'triangles' )
  await p.shader_from_file 'shader.wgsl'
  p.end()


  j = c.job()
  j.render_begin()
  j.render_obj( p, obj )
  j.render_end()
  j.gpu_send()


main()