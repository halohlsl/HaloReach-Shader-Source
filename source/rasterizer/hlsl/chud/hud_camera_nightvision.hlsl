//#line 2 "source\rasterizer\hlsl\hud_camera_nightvision.hlsl"


#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
#include "chud\hud_camera_nightvision_registers.fx"
//@generate screen

LOCAL_SAMPLER_2D(depth_sampler, 0);
LOCAL_SAMPLER_2D(color_sampler, 1);
LOCAL_SAMPLER_2D(mask_sampler, 2);

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


float4 default_ps(screen_output IN) : SV_Target
{
#if defined(pc) && (DX_VERSION == 9)
 	float4 color= sample2D(depth_sampler, IN.texcoord);
#else

	float2 texcoord= IN.texcoord;

	float mask= sample2D(mask_sampler, texcoord).r;

	// active values:	mask, texcoord (3)

	float4 color= 0.0f;
	if (mask > 0.0f)
	{
		float color_o;
		{
#ifdef xenon
			asm
			{
				tfetch2D color_o.x, texcoord, depth_sampler, OffsetX= 0, OffsetY= 0
			};
#else
			color_o.x = sample2D(depth_sampler, texcoord).r;
#endif
		}

		// active values:	mask, texcoord, color_o (4)

		int index;
		float pulse_boost;
		[isolate]
		{
			float value;
#ifdef xenon
			asm
			{
				tfetch2D value.b, texcoord, color_sampler, OffsetX= 0, OffsetY= 0

			};
#else
			value = sample2D(color_sampler, texcoord).b;
#endif
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
#ifdef xenon
			asm
			{
				tfetch2D color_px.x, texcoord, depth_sampler, OffsetX= 1, OffsetY= 0
				tfetch2D color_nx.x, texcoord, depth_sampler, OffsetX= -1, OffsetY= 0
				tfetch2D color_py.x, texcoord, depth_sampler, OffsetX= 0, OffsetY= 1
				tfetch2D color_ny.x, texcoord, depth_sampler, OffsetX= 0, OffsetY= -1
			};
#else
			color_px = depth_sampler.t.Sample(depth_sampler.s, texcoord, int2(1, 0));
			color_nx = depth_sampler.t.Sample(depth_sampler.s, texcoord, int2(-1, 0));
			color_py = depth_sampler.t.Sample(depth_sampler.s, texcoord, int2(0, 1));
			color_ny = depth_sampler.t.Sample(depth_sampler.s, texcoord, int2(0, -1));
#endif
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
