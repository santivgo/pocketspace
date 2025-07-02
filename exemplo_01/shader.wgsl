struct VertexIn {
    @location(0) pos: vec2<f32>,
    @location(1) color: vec4<f32>,
}

struct VertexOut {
    @builtin(position) pos: vec4<f32>,
    @location(0) color: vec4<f32>,
}

@vertex
fn vs_main(input: VertexIn) -> VertexOut {
    var output: VertexOut;
    output.pos = vec4<f32>( input.pos, 0.0, 1.0 );
    output.color = input.color;
    return output;
}



struct FragmentIn {
    @location(0) color: vec4<f32>
}

struct FragmentOut {
    @location(0) color: vec4<f32>
};

@fragment
fn fs_main(input: FragmentIn) -> FragmentOut {
    var out: FragmentOut;
    out.color = input.color;
    //out.color = vec4<f32>(0,0,1,1);
    return out;
}