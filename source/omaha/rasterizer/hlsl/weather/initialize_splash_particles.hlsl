////#line 1 "source\rasterizer\hlsl\weather\initialize_splash_particles.hlsl"
//@generate tiny_position

#if DX_VERSION == 11
// @compute_shader
#endif

#define VERTS_PER_DROP			4
#define DROP_TEXTURE_SIZE		128


#include "hlsl_constant_globals.fx"
#include "weather\splash_particles_registers.fx"

float4 initialize_particle()
{
	return float4(0.0f, 0.0f, 0.0f, 2.0f);
}

#if defined(pc) && (DX_VERSION == 9)

void default_vs(out float4 out_position : POSITION)		{ out_position= 0.0f; }
float4 default_ps() : COLOR0							{ return 0.0f; }

#elif defined(xenon) // XENON


//#ifdef VERTEX_SHADER


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

//#endif // VERTEX_SHADER


float4 export_stream_constant : register(c105);


float4 default_ps(
	in float2	pixel_coord	:	VPOS) : COLOR0
{
	float pixel_index= pixel_coord.x;
	float4 result=	initialize_particle();

	const float4 k_offset_const= { 0, 1, 0, 0 };
	asm {
		alloc export=1
		mad eA, pixel_index, k_offset_const, export_stream_constant
		mov eM0, result
	};

	return result;
}

#elif DX_VERSION == 11

#ifdef COMPUTE_SHADER

[numthreads(CS_INITIALIZE_SPLASH_PARTICLES_THREADS, 1, 1)]
void default_cs(in uint index : SV_DispatchThreadID)
{
	g_splash_particle_buffer[index] = initialize_particle();
}

#endif

#endif // XENON
