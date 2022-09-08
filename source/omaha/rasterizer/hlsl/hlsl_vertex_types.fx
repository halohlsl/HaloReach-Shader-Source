
//#line 2 "source\rasterizer\hlsl\hlsl_vertex_types.fx"

#ifndef _HLSL_VERTEX_TYPES_FX_
#define _HLSL_VERTEX_TYPES_FX_

#ifndef vertex_type
#error You need to define 'vertex_type' in the preprocessor
#endif

#define VERTEX_TYPE(type) VERTEX_TYPE_##type
#define IS_VERTEX_TYPE(type) (VERTEX_TYPE(vertex_type)== VERTEX_TYPE(type))

#define VERTEX_TYPE_s_world_vertex			0
#define VERTEX_TYPE_s_rigid_vertex			1
#define VERTEX_TYPE_s_skinned_vertex		2
#define VERTEX_TYPE_s_particle_model_vertex	3
#define VERTEX_TYPE_s_flat_world_vertex		4
#define VERTEX_TYPE_s_flat_rigid_vertex		5
#define VERTEX_TYPE_s_flat_skinned_vertex	6
#define VERTEX_TYPE_s_screen_vertex			7
#define VERTEX_TYPE_s_debug_vertex			8
#define VERTEX_TYPE_s_transparent_vertex	9
#define VERTEX_TYPE_s_particle_vertex		10
#define VERTEX_TYPE_s_contrail_vertex		11
#define VERTEX_TYPE_s_light_volume_vertex	12
#define VERTEX_TYPE_s_chud_vertex_simple	13
#define VERTEX_TYPE_s_chud_vertex_fancy		14
#define VERTEX_TYPE_s_decorator_vertex		15
#define VERTEX_TYPE_s_tiny_position_vertex	16
#define VERTEX_TYPE_s_patchy_fog_vertex		17
#define VERTEX_TYPE_s_water_vertex			18
#define VERTEX_TYPE_s_ripple_vertex			19
#define VERTEX_TYPE_s_implicit_vertex		20
#define VERTEX_TYPE_s_beam_vertex			21
#define VERTEX_TYPE_s_world_tessellated_vertex		22
#define VERTEX_TYPE_s_rigid_tessellated_vertex		23
#define VERTEX_TYPE_s_skinned_tessellated_vertex	24
#define VERTEX_TYPE_s_shader_cache_vertex			25
#define VERTEX_TYPE_s_instance_imposter_vertex		26
#define VERTEX_TYPE_s_object_imposter_vertex		27
//#define VERTEX_TYPE_s_rigid_vertex					28
//#define VERTEX_TYPE_s_skinned_vertex				29
#define VERTEX_TYPE_s_light_volume_pre_vertex		30


// data from application vertex buffer
struct s_world_vertex
{
    float4 position		:POSITION;
    float2 texcoord		:TEXCOORD0;
    float3 normal		:NORMAL;
    float3 tangent		:TANGENT;
};
typedef s_world_vertex s_flat_world_vertex;	// the normal/binormal/tangent are present, but ignored
typedef s_world_vertex s_world_tessellated_vertex;

struct s_rigid_vertex
{
    float4 position		:POSITION;
    float2 texcoord		:TEXCOORD0;
    float3 normal		:NORMAL;
    float3 tangent		:TANGENT;
};
typedef s_rigid_vertex s_flat_rigid_vertex;	// the normal/binormal/tangent are present, but ignored
typedef s_rigid_vertex s_rigid_tessellated_vertex;

struct s_skinned_vertex
{
    float4 position		:POSITION;
    float2 texcoord		:TEXCOORD0;
    float3 normal		:NORMAL;
    float3 tangent		:TANGENT;
#if DX_VERSION == 11
	uint4 node_indices 	:BLENDINDICES;
#else
	float4 node_indices :BLENDINDICES;
#endif
	float4 node_weights :BLENDWEIGHT;
};
typedef s_skinned_vertex s_flat_skinned_vertex;	// the normal/binormal/tangent are present, but ignored
typedef s_skinned_vertex s_skinned_tessellated_vertex;

struct s_screen_vertex
{
   float2 position		:POSITION;
   float2 texcoord		:TEXCOORD0;
   float4 color			:COLOR0;
};

struct s_debug_vertex
{
	float3 position		:POSITION;
	float4 color		:COLOR0;
};

struct s_transparent_vertex
{
	float3 position		:POSITION;
	float2 texcoord		:TEXCOORD0;
	float4 color		:COLOR0;
};

// lighting model vertex structures
struct s_lightmap_per_pixel
{
#if IS_VERTEX_TYPE(s_shader_cache_vertex)
    float4 texcoord	:TEXCOORD1;
#else
    float2 texcoord	:TEXCOORD1;
#endif
};

struct s_lightmap_per_vertex
{
    float3 color	:COLOR0;
};

struct s_particle_vertex
{
#if DX_VERSION == 11
	int index;
	uint2 address;
#else
	int index        :INDEX;

	// This is only present for the spawning particles
	float2 address	:TEXCOORD1;	// location within the particle storage buffer
#endif
	// The remaining fields are always accessed via explicit vfetches instead of implicitly
};

struct s_particle_model_vertex	// should be the same as s_particle_vertex
{
#if DX_VERSION == 11
	// model data
	float4 model_pos_sample    :POSITION0;
	float4 model_uv_sample     :TEXCOORD0;
	float4 model_normal_sample :NORMAL0;
#else
	int index        :INDEX;

	// This is only present for the spawning particles
	float2 address	:TEXCOORD1;	// location within the particle storage buffer
#endif
	// The remaining fields are always accessed via explicit vfetches instead of implicitly
};

struct s_contrail_vertex
{
#if DX_VERSION == 11
	int index;
#else
	int index        :INDEX;

	// This is only present for the spawning profiles
	float2 address	:TEXCOORD1;	// location within the contrail storage buffer
#endif

	// The remaining fields are always accessed via explicit vfetches instead of implicitly
};

struct s_light_volume_vertex
{
#if DX_VERSION == 11
	int index;
	int buffer_index;
#else
	int index        :INDEX;
#endif
};

struct s_beam_vertex
{
#if DX_VERSION == 11
	int index;
#else
	   int index        :INDEX;
#endif
};

struct s_chud_vertex_simple
{
	float2 position		:POSITION;
	float2 texcoord		:TEXCOORD0;
};

struct s_chud_vertex_fancy
{
	float3 position		:POSITION;
	float4 color		:COLOR0;
	float2 texcoord		:TEXCOORD0;
};

struct s_implicit_vertex
{
	float4 position		:POSITION;
	float2 texcoord		:TEXCOORD0;
};

struct s_decorator_vertex
{
	// vertex data (stream 0)
	float3 position		:	POSITION0;
	float2 texcoord		:	TEXCOORD0;

	// instance data (stream 1)
	float4 instance_position	:	POSITION1;
	float4 instance_orientation	:	NORMAL1;
	float4 instance_color		:	COLOR1;

	// also stream 2 => vertex index (int)
};

//	has been ingored
struct s_water_vertex
{
	float3 position		:	POSITION0;
};

//	has been ingored
struct s_ripple_particle_vertex
{
	float2 position		:	POSITION0;
};

struct s_tiny_position_vertex
{
	float4 position		:	POSITION0;
};

struct s_patchy_fog_vertex
{
	float4 position		:	POSITION0;
};

struct s_shader_cache_vertex
{
    float4 position		:POSITION;
    float2 texcoord		:TEXCOORD0;
    float3 normal		:NORMAL;
    float3 tangent		:TANGENT;
    float3 binormal		:BINORMAL;
	float4 light_param	:TEXCOORD1;
};

// vertex indices for both non-tessellated or tessellated geometry
#ifndef pc
struct s_vertex_type_trilist_index
{
	int3 index		:	INDEX;
	float3 uvw		:	BARYCENTRIC;
};
#endif //!pc

// refer to: _vertex_type_object_imposter
struct s_object_imposter_vertex
{
    float4 position					:POSITION;
    float3 normal					:NORMAL;
	float3 diffuse					:TEXCOORD1;
	float3 ambient					:TEXCOORD2;
	float4 specular_shininess		:TEXCOORD3;
	float4 change_colors_of_diffuse	:TEXCOORD4;
	float4 change_colors_of_specular:TEXCOORD5;
};

#if DX_VERSION == 11

struct s_big_battle_unit
{
	float4 velocity : TANGENT;
	float4 position_scale : BINORMAL;
	float4 forward : COLOR0;
	float4 left : COLOR1;
};

#endif

struct s_light_volume_pre_vertex
{
	int index        :INDEX;
};

#endif
