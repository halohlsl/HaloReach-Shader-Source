#ifndef _DECORATORS_REGISTERS_FX_
#ifndef DEFINE_CPP_CONSTANTS
#define _DECORATORS_REGISTERS_FX_
#endif

#if DX_VERSION == 9

// light data goes where node data would normally be
VERTEX_CONSTANT(int, v_simple_light_count, k_register_node_per_vertex_count);
VERTEX_CONSTANT(float4, v_simple_lights[4 * k_maximum_simple_light_count], k_register_node_start);

// per frame
VERTEX_CONSTANT(float4, v_cloud_motion, c230);

VERTEX_CONSTANT(float4, vs_antialias_scalars, c250);						//
VERTEX_CONSTANT(float4, vs_object_velocity, c251);							// velocity of the current object, world space per object (approx)	###ctchou $TODO we could compute this in the vertex shader as a function of the bones...
VERTEX_CONSTANT(float4, vs_camera_velocity, c252);

PIXEL_CONSTANT(float3, contrast, c13);


// per block/instance/decorator_set
VERTEX_CONSTANT(float4, instance_compression_offset, c240);
VERTEX_CONSTANT(float4, instance_compression_scale, c241);
// Instance data holds the index count of one instance, as well as an index offset
// for drawing index buffer subsets.
VERTEX_CONSTANT(float4, instance_data, c242);
VERTEX_CONSTANT(float4, translucency, c243);

// depends on type
VERTEX_CONSTANT(float4, wave_flow, c249);		// phase direction + frequency

VERTEX_CONSTANT(float4, instance_position_and_scale, c17);
VERTEX_CONSTANT(float4, instance_quaternion, c18);

#elif DX_VERSION == 11

CBUFFER_BEGIN(DecoratorsVS)
	CBUFFER_CONST(DecoratorsVS,			int,		v_simple_light_count,									k_vs_decorators_int_simple_light_count)
	CBUFFER_CONST(DecoratorsVS,			int3,		v_simple_light_count_pad,								k_vs_decorators_simple_light_count_pad)
	CBUFFER_CONST_ARRAY(DecoratorsVS,	float4, 	v_simple_lights, [5 * k_maximum_simple_light_count], 	k_vs_decorators_simple_lights)
	CBUFFER_CONST(DecoratorsVS,			float4,		v_cloud_motion,											k_vs_decorators_cloud_motion)
	CBUFFER_CONST(DecoratorsVS,			float4, 	vs_antialias_scalars, 									k_vs_decorators_antialias_scalars)
	CBUFFER_CONST(DecoratorsVS,			float4, 	vs_object_velocity, 									k_vs_decorators_object_velocity)
	CBUFFER_CONST(DecoratorsVS,			float4, 	vs_camera_velocity, 									k_vs_decorators_camera_velocity)
CBUFFER_END

CBUFFER_BEGIN(DecoratorsInstanceVS)
	CBUFFER_CONST(DecoratorsInstanceVS,	float4, 	instance_compression_offset,							k_vs_decorators_instance_compression_offset)
	CBUFFER_CONST(DecoratorsInstanceVS,	float4, 	instance_compression_scale,								k_vs_decorators_instance_compression_scale)
	CBUFFER_CONST(DecoratorsInstanceVS,	float4, 	instance_data,											k_vs_decorators_instance_data)
	CBUFFER_CONST(DecoratorsInstanceVS,	float4, 	translucency,											k_vs_decorators_translucency)
	CBUFFER_CONST(DecoratorsInstanceVS,	float4, 	wave_flow,												k_vs_decorators_wave_flow)
	CBUFFER_CONST(DecoratorsInstanceVS,	float4, 	instance_position_and_scale,							k_vs_decorators_instance_position_and_scale)
	CBUFFER_CONST(DecoratorsInstanceVS,	float4, 	instance_quaternion,									k_vs_decorators_instance_quaternion)
CBUFFER_END

CBUFFER_BEGIN(DecoratorsPS)
	CBUFFER_CONST(DecoratorsPS,			float3, 	contrast, 												k_ps_decorators_contrast)
	CBUFFER_CONST(DecoratorsPS,			float,	 	contrast_pad, 											k_ps_decorators_contrast_pad)
CBUFFER_END

#endif

#ifndef DEFINE_CPP_CONSTANTS
#define sun_direction v_analytical_light_direction
#define sun_color v_analytical_light_intensity
#endif

#endif
