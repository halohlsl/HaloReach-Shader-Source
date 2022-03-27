////#line 1 "source\rasterizer\hlsl\weather\update_splash_particles.hlsl"
//@generate tiny_position

#define DROP_TEXTURE_SIZE		128


#include "hlsl_constant_globals.fx"

#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#undef SAMPLER_CONSTANT
#include "weather\rain_registers.h"


#ifdef pc

void default_vs(out float4 out_position : POSITION)		{ out_position= 0.0f; }
float4 default_ps() : COLOR0							{ return 0.0f; }

#else // XENON


#ifdef VERTEX_SHADER
void default_vs(
	in int index						:	INDEX,
	out float4	out_position			:	POSITION)
{
	float2		verts[4]=
	{
		float2(-1.0f,-1.0f),
		float2( 1.0f,-1.0f),
		float2( 1.0f, 1.0f),
		float2(-1.0f, 1.0f),
	};

	out_position.xy=	verts[index];
	out_position.zw=	1.0f;
}
#endif // VERTEX_SHADER


#ifdef PIXEL_SHADER
sampler1D	splash_texture : register(s0);

float4 default_ps(
	in float2	splash_coord	:	VPOS) : COLOR0
{
	float pixel_index= splash_coord.x;

	float4 splash_data;
	asm
	{
		tfetch1D	splash_data.zyxw,	pixel_index,		splash_texture,		UnnormalizedTextureCoords= true,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled
	};

	splash_data.w += SPLASH_AGE_DELTA;
	
	const float4 k_offset_const= { 0, 1, 0, 0 };
	asm {
		alloc export=1
		mad eA, pixel_index, k_offset_const, export_stream_constant
		mov eM0, splash_data
	};	
	
	return splash_data;
}
#endif // PIXEL_SHADER

#endif // XENON