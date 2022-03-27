////#line 1 "source\rasterizer\hlsl\weather\initialize_splash_particles.hlsl"
//@generate tiny_position

#define VERTS_PER_DROP			4
#define DROP_TEXTURE_SIZE		128


#include "hlsl_constant_globals.fx"


#ifdef pc

void default_vs(out float4 out_position : POSITION)		{ out_position= 0.0f; }
float4 default_ps() : COLOR0							{ return 0.0f; }

#else // XENON


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
	float4 result=	float4(0.0f, 0.0f, 0.0f, 2.0f);
	
	const float4 k_offset_const= { 0, 1, 0, 0 };
	asm {
		alloc export=1
		mad eA, pixel_index, k_offset_const, export_stream_constant
		mov eM0, result
	};	

	return result;
}


#endif // XENON