////#line 1 "source\rasterizer\hlsl\weather\initialize_rain_particles.hlsl"
//@generate tiny_position

#define DROP_TEXTURE_SIZE		128


#include "hlsl_constant_globals.fx"


#if defined(pc) && (DX_VERSION == 9)

void default_vs(out float4 out_position : POSITION)		{ out_position= 0.0f; }
float4 default_ps() : COLOR0							{ return 0.0f; }

#else // XENON


//#ifdef VERTEX_SHADER


void default_vs(
	in uint index						:	SV_VertexID,
	out float4	out_position			:	SV_Position)
{
	float2		verts[4]=
	{
		float2(-1.0f,-1.0f),
		float2( 1.0f,-1.0f),
#if DX_VERSION == 9
		float2( 1.0f, 1.0f),
		float2(-1.0f, 1.0f),
#elif DX_VERSION == 11
		float2(-1.0f, 1.0f),
		float2( 1.0f, 1.0f),
#endif
	};

	out_position.xy=	verts[index];
	out_position.zw=	1.0f;
}

//#endif // VERTEX_SHADER


LOCAL_SAMPLER_2D(drop_texture, 0);

//float4		velocity :			register(c100);
//float4		center :			register(c101);
//float4		virtual_offset :	register(c102);
//float4		shadow_proj	:		register(c103);
//float4		shadow_depth :		register(c104);

float4 default_ps(
	SCREEN_POSITION_INPUT(drop_coord)) : SV_Target0
{
	float4 drop_data;
#ifdef xenon
	asm
	{
		tfetch2D	drop_data,	drop_coord.xy,	drop_texture,	UnnormalizedTextureCoords= true,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled
	};
#elif DX_VERSION == 11
	drop_data= drop_texture.t.Load(int3(drop_coord.xy, 0));
#endif

	return float4(drop_data.x, 1.0f, 1.0f, 1.0f);
}


#endif // XENON