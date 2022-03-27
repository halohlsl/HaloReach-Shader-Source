//#line 1 "source\rasterizer\hlsl\alpha_test.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "shared\atmosphere.fx"

#include "shared\render_target.fx"

VERTEX_CONSTANT(float4, lighting, k_alpha_test_shader_lighting_constant);

//@generate world
sampler2D basemap_sampler : register(s0);

struct alpha_test_output
{
	float4 position		:POSITION;
	float2 texcoord		:TEXCOORD0;
    float3 extinction	:COLOR0;// COLOR semantic will not clamp to [0,1].
    float3 inscatter	:COLOR1;// COLOR semantic will not clamp to [0,1].
};

alpha_test_output default_vs(vertex_type IN)
{
    alpha_test_output OUT;

    OUT.position= mul(float4(IN.position.xyz, 1.0f), View_Projection);
	OUT.texcoord= IN.texcoord;
	
	float3 inscatter;
	float extinction;

	compute_scattering(Camera_Position, OUT.position.xyz, inscatter, extinction);

	//OUT.extinction.xyz= extinction * lighting.rgb;
	//OUT.inscatter.xyz= inscatter;
	OUT.extinction.xyz= extinction * lighting.rgb;
	OUT.inscatter.xyz= float3(0, 0, 0);
	
    return OUT;
}

// pixel fragment entry points
accum_pixel default_ps(alpha_test_output IN) : COLOR
{
	float4 pixel= tex2D(basemap_sampler, IN.texcoord);
		
	clip(pixel.a-0.5f);
	
	pixel.rgb= (pixel.rgb * IN.extinction + IN.inscatter) * g_exposure.rrr;
	
	return convert_to_render_target(pixel, false, false);
}
