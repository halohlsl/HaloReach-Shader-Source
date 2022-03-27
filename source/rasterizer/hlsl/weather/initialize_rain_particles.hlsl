////#line 1 "source\rasterizer\hlsl\weather\initialize_rain_particles.hlsl"
//@generate tiny_position

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


sampler2D	drop_texture : register(s0);

float4		velocity :			register(c100);
float4		center :			register(c101);
float4		virtual_offset :	register(c102);
float4		shadow_proj	:		register(c103);
float4		shadow_depth :		register(c104);

float4 default_ps(
	in float2	drop_coord	:	VPOS) : COLOR0
{
	float4 drop_data;
	asm
	{
		tfetch2D	drop_data,	drop_coord.xy,	drop_texture,	UnnormalizedTextureCoords= true,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled
	};

	return float4(drop_data.x, 1.0f, 1.0f, 1.0f);
}


#endif // XENON