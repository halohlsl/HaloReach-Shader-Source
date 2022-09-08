////#line 1 "source\rasterizer\hlsl\weather\update_splash_particles.hlsl"
//@generate tiny_position

#if DX_VERSION == 11
// @compute_shader
#endif

#define DROP_TEXTURE_SIZE		128


#include "hlsl_constant_globals.fx"

#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#undef SAMPLER_CONSTANT
#include "weather\rain_registers.h"
#include "weather\splash_particles_registers.fx"

#if defined(PIXEL_SHADER) || defined(COMPUTE_SHADER)

void update_particle(inout float4 splash_data)
{
	splash_data.w += SPLASH_AGE_DELTA;
}

#endif

#if defined(pc) && (DX_VERSION == 9)

void default_vs(out float4 out_position : POSITION)		{ out_position= 0.0f; }
float4 default_ps() : COLOR0							{ return 0.0f; }

#elif defined(xenon) // XENON

#ifdef VERTEX_SHADER
void default_vs(
	in uint index						:	SV_VertexID,
	out float4	out_position			:	SV_Position)
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

float4 default_ps(
	SCREEN_POSITION_INPUT(splash_coord)) : SV_Target0
{
	float pixel_index= splash_coord.x;

	float4 splash_data;
	asm
	{
		tfetch1D	splash_data.,	pixel_index,		splash_data_texture,		UnnormalizedTextureCoords= true,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled
	};

	update_particle(splash_data);

	const float4 k_offset_const= { 0, 1, 0, 0 };
	asm {
		alloc export=1
		mad eA, pixel_index, k_offset_const, export_stream_constant
		mov eM0, splash_data
	};

	return splash_data;
}
#endif // PIXEL_SHADER

#elif DX_VERSION == 11

#ifdef COMPUTE_SHADER

[numthreads(CS_UPDATE_SPLASH_PARTICLES_THREADS, 1, 1)]
void default_cs(in uint index : SV_DispatchThreadID)
{
	float4 splash_data = g_splash_particle_buffer[index];
	update_particle(splash_data);
	g_splash_particle_buffer[index] = splash_data;
}

#endif

#endif // XENON