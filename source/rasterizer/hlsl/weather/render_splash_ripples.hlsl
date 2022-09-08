////#line 1 "source\rasterizer\hlsl\weather\render_splash_ripples.hlsl"
//@generate tiny_position

#define VERTS_PER_SPLASH		4
#define SPLASH_TEXTURE_SIZE		512


#include "hlsl_constant_globals.fx"

//#define QUAD_INDEX_MOD4
#include "shared\procedural_geometry.fx"

#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#undef SAMPLER_CONSTANT
#include "weather\rain_registers.h"
#include "weather\splash_particles_registers.fx"
#include "weather\splash_ripples_registers.fx"

#define RIPPLE_SIZE_SCALE (ripple_constants.x)
#define RIPPLE_SIZE_OFFSET (ripple_constants.y)
#define RIPPLE_TIME_SCALE (ripple_constants.z)

#if defined(pc) && (DX_VERSION == 9)

void default_vs(out float4 out_position : POSITION)		{ out_position= 0.0f; }
float4 default_ps() : COLOR0							{ return 0.0f; }

#else // XENON


#ifdef VERTEX_SHADER

// randomize:	lifetime?, size, rotation, flip, bitmap array, try relative add for intensity differences

void default_vs(
	in uint index						:	SV_VertexID,
#if DX_VERSION == 11
	in uint instance					:	SV_InstanceID,
#endif
	out float4	out_position			:	SV_Position,
	out float4	out_texcoord			:	TEXCOORD0,
	out float4  out_center				:	TEXCOORD1)
{
    // what raindrop are we?   4 verts per raindrop
#if DX_VERSION == 11
	uint splash_index= instance;
	uint vert_index= index;
#else
	float splash_index= floor(index * (1.0f / VERTS_PER_SPLASH) + (0.5f / VERTS_PER_SPLASH));
	float vert_index= index - splash_index * VERTS_PER_SPLASH;
#endif

	float4 random=		frac(splash_index * float4(321.7f, 843.6f, 1343.2f, 2151.5f));

	// fetch rain splash data
	float4 splash_data;
#ifdef xenon
	asm
	{
		tfetch1D	splash_data.zyxw,	splash_index,	splash_data_texture,		UnnormalizedTextureCoords= true,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled,	UseComputedLOD= false,  UseRegisterGradients=false
	};
#elif DX_VERSION == 11
	splash_data= g_splash_particle_buffer[splash_index];
#endif

	float3 splash_position_world=	splash_data.xyz;
	float  splash_time=				saturate(splash_data.w * RIPPLE_TIME_SCALE);

	float3 splash_to_camera_world=	splash_position_world - Camera_Position;
	float distance=	length(splash_to_camera_world.xyz);
	splash_to_camera_world /= distance;

	float2x3 basis;
	basis[0]= -Camera_Right;
	basis[1]= Camera_Up;
//	basis[2]= Camera_Forward;

	// make ripple more visible and growing in an uneven speed
	float size=			sqrt(splash_time) * RIPPLE_SIZE_SCALE * 3.0f + RIPPLE_SIZE_OFFSET;

	float2 local_pos=	generate_quad_point_centered_2d(vert_index);

	out_position=		float4(splash_position_world + size * mul(local_pos.xy, basis), 1.0f);
	out_position.xyz=	out_position.xyz + 0.1f * normalize(Camera_Position - out_position.xyz);

	out_position=		mul(out_position, transpose(view_projection));

	float alpha=		saturate(distance * SPLASH_NEAR_FADE_SCALE + SPLASH_NEAR_FADE_OFFSET);		// saturate(1.0f - splash_time) *

	if (alpha <= 0.0f)
	{
		out_position.xyz=	NaN;
	}

    out_texcoord.xy=    out_position.xy / out_position.w * float2(0.5f,-0.5f) + 0.5f;
	out_texcoord.z=		2.0f / size;
	out_texcoord.a=		alpha;

	out_center.xyz=		splash_position_world.xyz;
	out_center.w=		splash_time;
}

#endif // VERTEX_SHADER


#ifdef PIXEL_SHADER

float3 calculate_world_position(float2 pixel_position, float depth)
{
       float4 clip_space_position= float4(pixel_position.xy, depth, 1.0f);
       float4 world_space_position= mul(clip_space_position, transpose(texcoord_to_world));
       return world_space_position.xyz / world_space_position.w;
}


float4 default_ps(
	SCREEN_POSITION_INPUT(screen_position),
	in float4	texcoord			:	TEXCOORD0,					// texcoord.xy, size_scale, alpha
	in float4	center				:	TEXCOORD1) : SV_Target0		// world space center, time
{
//	grab world space position
	float depth;
#ifdef xenon
	asm
	{
		tfetch2D depth.x,	texcoord.xy, depth_texture,	UnnormalizedTextureCoords=false, MagFilter=point, MinFilter=point, MipFilter=point, AnisoFilter=disabled, OffsetX= +0.5, OffsetY= +0.5
	};
#elif DX_VERSION == 11
	depth.x= sample2D(depth_texture, texcoord).x;
#endif

	float3 world_position=		calculate_world_position(texcoord.xy, depth);

	float3	relative_position=	(world_position - center.xyz) * texcoord.z;
	float	relative_distance=	length(relative_position.xy);

	float2 splash_coord=	float2(relative_distance, center.w);
	float4 color;
#ifdef xenon
	asm
	{
		tfetch3D	color,
					splash_coord,
					splash_texture,
					MagFilter= linear,
					MinFilter= linear,
					MipFilter= linear,
					VolMagFilter=	point,
					VolMinFilter=	point,
					AnisoFilter=	disabled
//					UseComputedLOD=	false,
//					UseRegisterLOD=	false,
//					UseRegisterGradients= false
	};
#elif DX_VERSION == 11
	float4 splash_texcoord = convert_3d_texture_coord_to_array_texture(splash_texture, float3(splash_coord.xy, 0));
	color = lerp(
		splash_texture.t.Sample(splash_texture.s, splash_texcoord.xyz),
		splash_texture.t.Sample(splash_texture.s, splash_texcoord.xyw),
		frac(splash_texcoord.z));
#endif
	float amount=	(color.g * (2 * 0.5) - (2 * 0.5 * 0.498031616));

	color=	float4(0.0f, amount * relative_position.xy + 0.5, color.a * texcoord.a);

	return color;
}

#endif // PIXEL_SHADER

#endif // XENON