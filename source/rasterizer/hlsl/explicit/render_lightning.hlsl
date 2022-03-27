////#line 1 "source\rasterizer\hlsl\explicit\render_lightning.hlsl"
//@generate tiny_position

#define VERTS_PER_PARTICLE		4
#define SPLASH_TEXTURE_SIZE		512


#include "hlsl_constant_globals.fx"

#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#undef SAMPLER_CONSTANT


#ifdef pc
void default_vs(out float4 out_position : POSITION)		{ out_position= 0.0f; }
float4 default_ps() : COLOR0							{ return 0.0f; }
#else // XENON


#ifdef VERTEX_SHADER

sampler2D	data_texture : register(s0);

float4		g_read_transform : register(c100);

#define SPLASH_SIZE 0.08f
#define SPLASH_OFFSET -0.04f

void default_vs(
	in int index						:	INDEX,
	out float4	out_position			:	POSITION,
	out float4	out_texcoord			:	TEXCOORD0)
{
	float3		verts[4]=
	{
		float3( 0.0f, 0.0f, 0.0f),
		float3( 1.0f, 0.0f, 0.0f),
		float3( 1.0f, 1.0f, 0.0f),
		float3( 0.0f, 1.0f, 0.0f),
	};

    // what raindrop are we?   4 verts per raindrop
    float	render_index=	floor(index * (1.0f / VERTS_PER_PARTICLE) + (0.5f / VERTS_PER_PARTICLE));
	float2 particle_index=	render_index * g_read_transform.xy + g_read_transform.zw;
	
	float vert_index= index - particle_index * VERTS_PER_PARTICLE;

	// fetch rain splash data
	float4 data;
	asm
	{
		tfetch2D	data.zyxw,	particle_index.xy,	data_texture,		UnnormalizedTextureCoords= true,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled,	UseComputedLOD= false,  UseRegisterGradients=false
	};

	float3 position_world=		data.xyz;
	float  time=				1.0f;	// splash_data.w;
	
	float3 splash_to_camera_world=	position_world - Camera_Position;
	float distance=	length(splash_to_camera_world.xyz);
	splash_to_camera_world /= distance;
	
	float2x3 basis;
	basis[0]= -Camera_Right;
	basis[1]= Camera_Up;
//	basis[2]= Camera_Forward;
	
	float2 local_pos=	verts[vert_index].xy * SPLASH_SIZE + SPLASH_OFFSET;
	out_position=		float4(position_world + mul(local_pos.xy, basis), 1.0f);
	out_position=		mul(out_position, View_Projection);
	
	float alpha=		saturate(1.0f - time);	//  * saturate(distance * SPLASH_NEAR_FADE_SCALE + SPLASH_NEAR_FADE_OFFSET);
	
//	if (alpha <= 0.0f)
//	{
//		out_position.xyz=	NaN;
//	}

	out_texcoord.a=		alpha * 0.5f;
	out_texcoord.xy=	verts[vert_index].xy;
	out_texcoord.z=		0.0f;
}

#endif // VERTEX_SHADER


#ifdef PIXEL_SHADER

sampler2D	splash_texture : register(s0);

float4 g_color : register(c100);

float4 default_ps(
	in float4	texcoord			:	TEXCOORD0) : COLOR0
{
	texcoord.xy -= 0.5f;
	float scale=	saturate(1.0f - length(texcoord.xy) * 2.0f);
//	float4 color=	tex2D(splash_texture, texcoord.xy);
//	color.rgb *=	color.a;
//	color.rgba *=	splash_tint.rgba;
//	color.rgba *=	texcoord.a;
//	return color;
//	return float4(0.6f * scale, 0.1f * scale, 1.0f * scale, 1.0f/8.0f/32.0f);
	return float4(g_color.rgb * scale, 1.0f / 8.0f / 32.0f);
}

#endif // PIXEL_SHADER

#endif // XENON