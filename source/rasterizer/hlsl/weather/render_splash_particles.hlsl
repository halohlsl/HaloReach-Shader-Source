////#line 1 "source\rasterizer\hlsl\weather\render_splash_particles.hlsl"
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
	out float4	out_texcoord			:	TEXCOORD0)
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
	float  splash_time=				splash_data.w;

	float3 splash_to_camera_world=	splash_position_world - Camera_Position;
	float distance=	length(splash_to_camera_world.xyz);
	splash_to_camera_world /= distance;

	float2x3 basis;
	basis[0]= -Camera_Right;
	basis[1]= Camera_Up;
//	basis[2]= Camera_Forward;

	float2 local_pos=	(generate_quad_point_2d(vert_index) * SPLASH_SIZE + SPLASH_OFFSET) * saturate(splash_time) * (1.0f + random.x * 0.5f);

	// randomly flip left-right
	local_pos.x *=		sign(random.y - 0.5);

	out_position=		float4(splash_position_world + mul(local_pos.xy, basis), 1.0f);
	out_position=		mul(out_position, transpose(view_projection));

	float alpha=		saturate(1.0f - splash_time) * saturate(distance * SPLASH_NEAR_FADE_SCALE + SPLASH_NEAR_FADE_OFFSET);

	if (alpha <= 0.0f)
	{
		out_position.xyz=	NaN;
	}

	out_texcoord.a=		alpha;
	out_texcoord.xy=	generate_quad_point_2d(vert_index);
	out_texcoord.z=		random.z;
}

#endif // VERTEX_SHADER


#ifdef PIXEL_SHADER

LOCAL_SAMPLER_2D_ARRAY(splash_texture, 0);

float4 default_ps(
	SCREEN_POSITION_INPUT(screen_position),
	in float4	texcoord			:	TEXCOORD0) : SV_Target0
{
//	float4 color=	tex2D(splash_texture, texcoord.xy);

	float4 color;
#ifdef xenon
	asm
	{
		tfetch3D	color,
					texcoord.xyz,
					splash_texture,
					MagFilter= linear,
					MinFilter= linear,
					MipFilter= linear,
					VolMagFilter=	point,
					VolMinFilter=	point,
					AnisoFilter= disabled,
					LODBias= -0.5
	};
#elif DX_VERSION == 11
	float4 splash_texcoord = convert_3d_texture_coord_to_array_texture(splash_texture,  texcoord.xyz);
	color = lerp(
		splash_texture.t.Sample(splash_texture.s, splash_texcoord.xyz),
		splash_texture.t.Sample(splash_texture.s, splash_texcoord.xyw),
		frac(splash_texcoord.z));
#endif

	// convert alpha-blend -> premultiplied alpha
//	color.rgb	*=	color.a;

	// tint, fade
	color.rgba *=	splash_tint.rgba;
	color.a *=		texcoord.a;

	// adjust to double-multiply form, transparents become 50% gray
	color.rgb=		lerp(0.5f, color.rgb, saturate(color.a));
#ifdef xenon
	color.rgb /= 32.0f;
#endif

	return color;
}

#endif // PIXEL_SHADER

#endif // XENON