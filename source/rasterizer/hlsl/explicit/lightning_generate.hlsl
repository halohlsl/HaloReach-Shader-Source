//#line 1 "source\rasterizer\hlsl\explicit\lightning_generate.hlsl"

//@generate tiny_position
//@entry default
//					= interpolate and sampled offset
//@entry albedo
//					= initialize line
//@entry static_sh
//					= initialize fork and sampled offset
//@entry active_camo
//					= full multisample combined frequencies
//@entry shadow_apply
//					= full multisample reading beam coords from previous texture

#include "hlsl_constant_globals.fx"


#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT


#ifdef pc
void albedo_vs(out float4 out_position : POSITION)			{ out_position= 0.0f; }
void default_vs(out float4 out_position : POSITION)			{ out_position= 0.0f; }
void static_sh_vs(out float4 out_position : POSITION)		{ out_position= 0.0f; }
void active_camo_vs(out float4 out_position : POSITION)		{ out_position= 0.0f; }
void shadow_apply_vs(out float4 out_position : POSITION)	{ out_position= 0.0f; }
float4 albedo_ps() : COLOR0									{ return 0.0f; }
float4 default_ps() : COLOR0								{ return 0.0f; }
float4 static_sh_ps() : COLOR0								{ return 0.0f; }
float4 active_camo_ps() : COLOR0							{ return 0.0f; }
float4 shadow_apply_ps() : COLOR0							{ return 0.0f; }
#else // XENON


sampler2D	bolt_texture : register(s0);
sampler2D	random_texture : register(s1);

float4 g_read_transform				: register(c100);
float4 g_write_transform			: register(c101);
float4 g_random_transform			: register(c102);
float4 g_export_stream_constant		: register(c103);
float4 g_frequency_scale			: register(c104);
float4 g_envelope_transform			: register(c105);
float4 g_value_transform_0			: register(c108);
float4 g_value_transform_1			: register(c109);

#define MAX_SAMPLES 8
float4 g_sample_transform[MAX_SAMPLES] : register(c112);
float4 g_sample_amplitude[MAX_SAMPLES] : register(c120);

#ifdef VERTEX_SHADER
void albedo_vs(
	in int index						:	INDEX)
{
	float4 value=			index * g_value_transform_0 + g_value_transform_1;
	float write_index=		index * g_write_transform.x + g_write_transform.y;
					
	const float4 k_offset_const= { 0, 1, 0, 0 };
	asm {
		alloc export=1
		mad eA, write_index, k_offset_const, g_export_stream_constant
		mov eM0, value
	};	
}

void default_vs(
	in int index						:	INDEX)
{
	float2 left_texcoord=		index * g_read_transform.xy + g_read_transform.zw;
	float2 right_texcoord=		index * g_read_transform.xy + g_read_transform.zw + g_read_transform.xy;

	float4 left;
	float4 right;
	asm
	{
		tfetch2D	left.zyxw,	left_texcoord,	bolt_texture,	UnnormalizedTextureCoords= true,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled,	UseComputedLOD= false
		tfetch2D	right.zyxw,	right_texcoord,	bolt_texture,	UnnormalizedTextureCoords= true,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled,	UseComputedLOD= false
	};
	float4 center=	(left + right) * 0.5f;

	float2 random_texcoord=		g_random_transform.xy * index + g_random_transform.zw;
	float4 random;
	asm
	{
		tfetch2D	random,	random_texcoord,	random_texture,	UnnormalizedTextureCoords= false,	MagFilter= linear,	MinFilter= linear,	MipFilter= point,	AnisoFilter= disabled,	UseComputedLOD= false
	};
	random=	(random - 0.5f);

	// ###ctchou $TODO frequency scale should be a 3x3 transform -- so we can scale along arbitrary axes
	center += (random) * pow(g_frequency_scale, 0.90) * 6.5;
	
	float write_index=		index * g_write_transform.x + g_write_transform.y;
					
	const float4 k_offset_const= { 0, 1, 0, 0 };
	asm {
		alloc export=1
		mad eA, write_index, k_offset_const, g_export_stream_constant
		mov eM0, center
	};
}

void static_sh_vs(
	in int index						:	INDEX)
{
	float2 curr_texcoord=			g_value_transform_0.zw;
	float2 prev_texcoord=			g_value_transform_0.zw - g_value_transform_0.xy;

	float4 curr;
	float4 prev;
	asm
	{
		tfetch2D	curr.zyxw,	curr_texcoord,	bolt_texture,	UnnormalizedTextureCoords= true,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled,	UseComputedLOD= false
		tfetch2D	prev.zyxw,	prev_texcoord,	bolt_texture,	UnnormalizedTextureCoords= true,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled,	UseComputedLOD= false
	};
	
	float2 random_texcoord=		g_random_transform.xy * index + g_random_transform.zw;
	float4 random;
	asm
	{
		tfetch2D	random,	random_texcoord,	random_texture,	UnnormalizedTextureCoords= false,	MagFilter= linear,	MinFilter= linear,	MipFilter= point,	AnisoFilter= disabled,	UseComputedLOD= false
	};
	random=	(random - 0.5f);

	float4 next=			2 * curr - prev;
	next += (random) * pow(g_frequency_scale, 0.90) * 6.5;

	float4 value=			lerp(curr, next, index);
	float write_index=		index * g_write_transform.x + g_write_transform.y;
					
	const float4 k_offset_const= { 0, 1, 0, 0 };
	asm {
		alloc export=1
		mad eA, write_index, k_offset_const, g_export_stream_constant
		mov eM0, value
	};	
}


void active_camo_vs(
	in int index						:	INDEX)
{
	// calculate generic envelope (0..1 triangle wave over the bolt)
	float envelope=		abs(index * g_envelope_transform.x + g_envelope_transform.y) * g_envelope_transform.z + g_envelope_transform.w;

	// accumulate samples
	float4 value=	0.0f;
	for (int sample_index= 0; sample_index < MAX_SAMPLES; sample_index++)
	{
		float2 sample_texcoord=		index * g_sample_transform[sample_index].xy + g_sample_transform[sample_index].zw;
		float4 sample;
		asm
		{
			tfetch2D	sample,	sample_texcoord,	random_texture,	UnnormalizedTextureCoords= true,	MagFilter= linear,	MinFilter= linear,	MipFilter= point,	AnisoFilter= disabled,	UseComputedLOD= false
		};
		sample=	(2 * sample - 1.0f);

		value += (sample) * g_sample_amplitude[sample_index].x * saturate(envelope * g_sample_amplitude[sample_index].w);		
	}

	// ###ctchou $TODO we should rotate value by a 3x3 matrix to align the amplitude scales to the bolt direction .. so we can scale samples parallel or transverse to the beam

	// add in base beam location
	value	+=	index * g_value_transform_0 + g_value_transform_1;

	// write result!
	float write_index=		index * g_write_transform.x + g_write_transform.y;
	const float4 k_offset_const= { 0, 1, 0, 0 };
	asm {
		alloc export=1
		mad eA, write_index, k_offset_const, g_export_stream_constant
		mov eM0, value
	};
}


void shadow_apply_vs(
	in int index						:	INDEX)
{
	// accumulate samples
	float4 value=	0.0f;
	for (int sample_index= 0; sample_index < MAX_SAMPLES; sample_index++)
	{
		float2 sample_texcoord=		(index + g_value_transform_1.z) * g_sample_transform[sample_index].xy + g_sample_transform[sample_index].zw;
		float4 sample;
		asm
		{
			tfetch2D	sample,	sample_texcoord,	random_texture,	UnnormalizedTextureCoords= true,	MagFilter= linear,	MinFilter= linear,	MipFilter= point,	AnisoFilter= disabled,	UseComputedLOD= false
		};
		sample=	(2 * sample - 1.0f);

		value += (sample) * g_sample_amplitude[sample_index];		
	}

	// ###ctchou $TODO we should rotate value by a 3x3 matrix to align the amplitude scales to the bolt direction .. so we can scale samples parallel or transverse to the beam

	// apply envelope		###ctchou $TODO improve this
	value *=	saturate(index / 32.0f);

	// add in base beam location
	float2 curr_texcoord=			g_value_transform_0.zw;
	float2 prev_texcoord=			g_value_transform_0.xy;
	float4 curr;
	float4 prev;
	asm
	{
		tfetch2D	curr.zyxw,	curr_texcoord,	bolt_texture,	UnnormalizedTextureCoords= true,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled,	UseComputedLOD= false
		tfetch2D	prev.zyxw,	prev_texcoord,	bolt_texture,	UnnormalizedTextureCoords= true,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled,	UseComputedLOD= false
	};
	
	value	+=	lerp(curr, prev, index * g_value_transform_1.x + g_value_transform_1.y);

	// write result!
	float write_index=		index * g_write_transform.x + g_write_transform.y;
	const float4 k_offset_const= { 0, 1, 0, 0 };
	asm {
		alloc export=1
		mad eA, write_index, k_offset_const, g_export_stream_constant
		mov eM0, value
	};
}


#endif // VERTEX_SHADER



#ifdef PIXEL_SHADER
float4 albedo_ps() : COLOR0			{	return 0.0f;	}
float4 default_ps() : COLOR0		{	return 0.0f;	}
float4 static_sh_ps() : COLOR0		{	return 0.0f;	}
float4 active_camo_ps() : COLOR0	{	return 0.0f;	}
float4 shadow_apply_ps() : COLOR0	{	return 0.0f;	}
#endif // PIXEL_SHADER

#endif // XENON