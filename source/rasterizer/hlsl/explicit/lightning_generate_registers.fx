#define MAX_SAMPLES 8

#if DX_VERSION == 9

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

float4 g_sample_transform[MAX_SAMPLES] : register(c112);
float4 g_sample_amplitude[MAX_SAMPLES] : register(c120);

#elif DX_VERSION == 11

CBUFFER_BEGIN(LightningGenerateCS)
	CBUFFER_CONST(LightningGenerateCS,			float4,			g_read_transform,						k_lightning_generate_read_transform)
	CBUFFER_CONST(LightningGenerateCS,			float4,			g_write_transform,						k_lightning_generate_write_transform)
	CBUFFER_CONST(LightningGenerateCS,			float4,			g_random_transform,						k_lightning_generate_random_transform)
	CBUFFER_CONST(LightningGenerateCS,			float4,			g_frequency_scale,						k_lightning_frequency_scale)
	CBUFFER_CONST(LightningGenerateCS,			float4,			g_envelope_transform,					k_lightning_envelope_transform)
	CBUFFER_CONST(LightningGenerateCS,			float4,			g_value_transform_0,					k_lightning_value_transform_0)
	CBUFFER_CONST(LightningGenerateCS,			float4,			g_value_transform_1,					k_lightning_value_transform_1)
	CBUFFER_CONST_ARRAY(LightningGenerateCS,	float4,			g_sample_transform, [MAX_SAMPLES],		k_lightning_sample_transform)
	CBUFFER_CONST_ARRAY(LightningGenerateCS,	float4,			g_sample_amplitude, [MAX_SAMPLES],		k_lightning_sample_amplitude)
CBUFFER_END

COMPUTE_TEXTURE_AND_SAMPLER(_2D,	random_texture, 	k_lightning_random_texture,		1);

RW_BUFFER(g_lightning_buffer, k_lightning_buffer, float4, 0);

#endif
