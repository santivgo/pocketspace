struct VertexIn {
    @location(0) pos: vec3<f32>,
    @location(1) color: vec4<f32>
}

struct VertexOut {
    @builtin(position) pos: vec4<f32>,
    @location(0) color: vec4<f32>
}

@vertex
fn vs_main(input: VertexIn) -> VertexOut {
    var output: VertexOut;

    let p = vec4<f32>( input.pos, 1 );
    
    output.pos = p;
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
    return out;
}