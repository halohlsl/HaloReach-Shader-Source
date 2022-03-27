//#line 2 "source\rasterizer\hlsl\hud_camera_nightvision.hlsl"


#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen


sampler2D depth_sampler : register(s0);
sampler2D color_sampler : register(s1);
sampler2D mask_sampler : register(s2);

float4 falloff : register(c94);
float4x4 screen_to_world : register(c95);
float4 ping : register(c99);
float4 colors[4][2] : register(c100);


float3 calculate_world_position(float2 texcoord, float depth)
{
	float4 clip_space_position= float4(texcoord.xy, depth, 1.0f);
	float4 world_space_position= mul(clip_space_position, transpose(screen_to_world));
	return world_space_position.xyz / world_space_position.w;
}

float calculate_pixel_distance(float2 texcoord, float depth)
{
	float3 delta= calculate_world_position(texcoord, depth);
	float pixel_distance= sqrt(dot(delta, delta));
	return pixel_distance;
}

float evaluate_smooth_falloff(float distance)
{
//	constant 1.0, then smooth falloff to zero at a certain distance:
//
//	at distance D
//	has value (2^-C)		C=8  (1/256)
//	falloff sharpness S		S=8
//	let B= (C^(1/S))/D		stored in falloff.x
//	
//		equation:	f(x)=	2^(-(x*B)^S)			NOTE: for small S powers of 2, this can be expanded almost entirely in scalar ops
//

	return exp2(-pow(distance * falloff.x, 8));
}


float4 default_ps(screen_output IN) : COLOR
{
#ifdef pc
 	float4 color= tex2D(depth_sampler, IN.texcoord);
 #else

	float2 texcoord= IN.texcoord;
	
	float mask= tex2D(mask_sampler, texcoord).r;

	// active values:	mask, texcoord (3)
	
	float4 color= 0.0f;	
	if (mask > 0.0f)
	{
		float color_o;
		{
			asm
			{
				tfetch2D color_o.x, texcoord, depth_sampler, OffsetX= 0, OffsetY= 0
			};	
		}

		// active values:	mask, texcoord, color_o (4)

		int index;
		float pulse_boost;
		[isolate]
		{
			float value;
			asm
			{
				tfetch2D value.b, texcoord, color_sampler, OffsetX= 0, OffsetY= 0
			};	
			index= floor(value * 4 + 0.5f);
		
			float pixel_distance= calculate_pixel_distance(texcoord, color_o);
			mask *= evaluate_smooth_falloff(pixel_distance);
			// calculate pulse
			{
				float ping_distance= ping.x;
				float after_ping= (ping_distance - pixel_distance);		// 0 at wavefront, positive closer to player
				pulse_boost= pow(saturate(1.0f + ping.z * after_ping), 4.0f) * step(pixel_distance, ping_distance);
			}
		}

		// active values:	mask, texcoord, color_o, pulse_boost, index (5/6)

		float gradient_magnitude;
//		[isolate]
		{
			float color_px, color_nx;
			float color_py, color_ny;
			asm
			{
				tfetch2D color_px.x, texcoord, depth_sampler, OffsetX= 1, OffsetY= 0
				tfetch2D color_nx.x, texcoord, depth_sampler, OffsetX= -1, OffsetY= 0
				tfetch2D color_py.x, texcoord, depth_sampler, OffsetX= 0, OffsetY= 1
				tfetch2D color_ny.x, texcoord, depth_sampler, OffsetX= 0, OffsetY= -1
			};
			float2 laplacian;
			laplacian.x= (color_px + color_nx) - 2 * color_o;
			laplacian.y= (color_py + color_ny) - 2 * color_o;
			gradient_magnitude= saturate(sqrt(dot(laplacian.xy, laplacian.xy)) / color_o.r);		//
		}
		
		// active values:	mask, pulse_boost, index (2/3)	
		
		{
			// convert to [0..4]
			float3 pulse_color= colors[index][1];
			float4 default_color= colors[index][0];
			
			color.rgb= gradient_magnitude * (default_color.rgb + pulse_color.rgb * pulse_boost);
			color.a= default_color.a * LDR_ALPHA_ADJUST;
			
			color *= mask;
		}
	}
#endif

	return color;
}
