/*
PARTICLE_RENDER.FX
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
11/14/2005 4:14:31 PM (davcook)

Shaders for particle renders, quad manufacture
*/

// Leave the skinning constant registers free for use
#define SCOPE_MESH_DEFAULT
#define IGNORE_SKINNING_NODES

// Don't allocate any constant space for properties
#define PARTICLE_NO_PROPERTY_EVALUATE 1
#if defined(xenon) || (DX_VERSION == 11)
#define DISTORTION_MULTISAMPLED 1
#else
#define DISTORTION_MULTISAMPLED 0
#endif

#include "shared\blend.fx"


#if (!defined(BLEND_MODE_OFF))
	// vertex shader needs to handle all cases including transparent:
	#define SCOPE_TRANSPARENTS
#endif // BLEND_MODE_OFF


#include "hlsl_constant_globals.fx"
#if DX_VERSION == 11
#include "effects\particle_state_buffer.fx"
#include "effects\particle_index_registers.fx"
#endif
#include "hlsl_vertex_types.fx"
#include "shared\spherical_harmonics.fx"

#include "effects\register_group.fx"

#define _register_group_mesh_variants	5
#define _register_group_sprite_frames	6


#include "effects\particle_render_registers.fx"	// must come before particle_common.fx
#include "effects\particle_update_registers.fx"

#ifdef VERTEX_SHADER
#include "effects\function_utilities.fx"
#include "effects\particle_common.fx"

#ifdef SCOPE_TRANSPARENTS
	#ifndef pc
		#define FOG_ENABLED
	#endif // pc
	#include "shared\atmosphere.fx"
#endif // SCOPE_TRANSPARENTS
#endif // VERTEX_SHADER

#include "shared\packed_vector.fx"


//This comment causes the shader compiler to be invoked for certain types
//@generate s_particle_vertex

//#define PARTICLE_DEBUG_VAR 1	// uncomment this to have some value appear in the Pix Mesh window (hasn't been working for some reason)

#define BLEND_MODE_SELF_ILLUM (TEST_CATEGORY_OPTION(blend_mode, additive) || TEST_CATEGORY_OPTION(blend_mode, add_src_times_srcalpha))
#define IS_DISTORTION_PARTICLE (!TEST_CATEGORY_OPTION(specialized_rendering, none))
#define DOUBLE_SPRITE_TEXCOORD (TEST_CATEGORY_OPTION(frame_blend, on) || TEST_CATEGORY_OPTION(albedo, palettized_plasma) || TEST_CATEGORY_OPTION(albedo, palettized_2d_plasma))

#if DX_VERSION == 9
// This is a hack to prevent the shader compiler from using the tail of the constant space...
extern float4x4 dummy : register(c252);
#endif

// Extern variables which come from shader
PARAM(float, starting_uv_scale);
PARAM(float, ending_uv_scale);
PARAM(float4, self_illum_color);
PARAM(float, bump_contrast);
PARAM(float, bump_randomness);
PARAM(float, contrast_scale);
PARAM(float, contrast_offset);

#include "effects\particle_render_state.fx"

#if DX_VERSION == 9

PARAM_STRUCT(s_motion_blur_state, g_motion_blur_state);
PARAM_STRUCT(s_sprite_definition, g_sprite);
PARAM_STRUCT(s_render_state, g_render_state);

//BEGIN_REGISTER_GROUP(mesh_variants)
PARAM_STRUCT(s_mesh_variant_list, g_all_mesh_variants);
//END_REGISTER_GROUP(mesh_variants)

BEGIN_REGISTER_GROUP(sprite_frames)
PARAM_STRUCT(s_sprite_frame_list, g_all_sprite_frames);
END_REGISTER_GROUP(sprite_frames)

#endif



struct s_particle_render_vertex
{
    float4 m_position;
    float2 m_texcoord_sprite0;	// consecutive frames of an animated bitmap
    float2 m_texcoord_sprite1;
    float2 m_texcoord_billboard;
    float m_frame_blend;		// avoid using interpolator for constant-per-particle value?		Is it faster to re-fetch the constant from the vertex buffer, rather than interpolate?
    float m_black_point;		// avoid using interpolator for constant-per-particle value?
    float m_palette;			// avoid using interpolator for constant-per-particle value?
    float4 m_color;				// COLOR semantic will not clamp to [0,1].
    float3 m_color_add;			// COLOR semantic will not clamp to [0,1].
#ifdef PARTICLE_DEBUG_VAR
	float4 m_debug_var;	// some value to view in Pix
#endif
	float3 m_normal;
	float3 m_binormal;
	float3 m_tangent;
	float m_depth;
};

struct s_particle_interpolators
{
	float4 m_position0	:SV_Position;
	float4 m_color0		:COLOR0;
	float4 m_color1		:COLOR1;
	float4 m_texcoord0	:TEXCOORD0;
	float4 m_texcoord1	:TEXCOORD1;
	float4 m_texcoord2	:TEXCOORD2;
#ifdef PARTICLE_DEBUG_VAR
	float4 m_texcoord3	:TEXCOORD3;
#endif
};

// We can save interpolator cost by eliminating unused interpolators from particular pixel shaders.
// But that causes the vertex shader to get patched at runtime, which is a big CPU hit.
// So instead we share interpolators for various purposes, and hope they never conflict
s_particle_interpolators write_particle_interpolators(s_particle_render_vertex VERTEX)
{
	s_particle_interpolators INTERPOLATORS;

	INTERPOLATORS.m_position0= VERTEX.m_position;
	INTERPOLATORS.m_color0= VERTEX.m_color;
	INTERPOLATORS.m_color1= IS_DISTORTION_PARTICLE
		? float4(VERTEX.m_tangent, VERTEX.m_depth)
		: float4(VERTEX.m_color_add, VERTEX.m_depth);
	INTERPOLATORS.m_texcoord0= float4(VERTEX.m_texcoord_sprite0, VERTEX.m_texcoord_sprite1);
	INTERPOLATORS.m_texcoord1= float4(VERTEX.m_frame_blend, VERTEX.m_black_point, VERTEX.m_texcoord_billboard);
	INTERPOLATORS.m_texcoord2= IS_DISTORTION_PARTICLE
		? float4(VERTEX.m_binormal, VERTEX.m_palette)
		: ((TEST_CATEGORY_OPTION(lighting, per_pixel_smooth) || TEST_CATEGORY_OPTION(lighting, smoke_lighting))
			? float4(VERTEX.m_normal, VERTEX.m_palette)
			: float4(0.0f, 0.0f, 0.0f, VERTEX.m_palette));
#ifdef PARTICLE_DEBUG_VAR
	INTERPOLATORS.m_texcoord3= VERTEX.m_debug_var;
#endif

	return INTERPOLATORS;
}

s_particle_render_vertex read_particle_interpolators(s_particle_interpolators INTERPOLATORS)
{
	s_particle_render_vertex VERTEX;

	VERTEX.m_position= INTERPOLATORS.m_position0;
	VERTEX.m_color= INTERPOLATORS.m_color0;
	VERTEX.m_tangent= IS_DISTORTION_PARTICLE
		? INTERPOLATORS.m_color1.xyz
		: float3(0.0f, 0.0f, 0.0f);
	VERTEX.m_color_add= IS_DISTORTION_PARTICLE
		? float3(0.0f, 0.0f, 0.0f)
		: INTERPOLATORS.m_color1.xyz;
	VERTEX.m_depth= INTERPOLATORS.m_color1.w;
	VERTEX.m_texcoord_sprite0= INTERPOLATORS.m_texcoord0.xy;
	VERTEX.m_texcoord_sprite1= INTERPOLATORS.m_texcoord0.zw;
	VERTEX.m_frame_blend= INTERPOLATORS.m_texcoord1.x;
	VERTEX.m_black_point= INTERPOLATORS.m_texcoord1.y;
	VERTEX.m_texcoord_billboard= INTERPOLATORS.m_texcoord1.zw;
	VERTEX.m_binormal= IS_DISTORTION_PARTICLE
		? INTERPOLATORS.m_texcoord2.xyz
		: float3(0.0f, 0.0f, 0.0f);
	VERTEX.m_normal= (TEST_CATEGORY_OPTION(lighting, per_pixel_smooth) || TEST_CATEGORY_OPTION(lighting, smoke_lighting))
		? INTERPOLATORS.m_texcoord2.xyz
		: float3(0.0f, 0.0f, 0.0f);
	VERTEX.m_palette= INTERPOLATORS.m_texcoord2.w;
#ifdef PARTICLE_DEBUG_VAR
	VERTEX.m_debug_var= INTERPOLATORS.m_texcoord3;
#endif

	return VERTEX;
}

#ifdef VERTEX_SHADER
#if !defined(pc) || (DX_VERSION == 11)

#define _particle_billboard_type_screen_facing			0
#define _particle_billboard_type_camera_facing			1
#define _particle_billboard_type_screen_parallel		2
#define _particle_billboard_type_screen_perpendicular	3
#define _particle_billboard_type_screen_vertical		4
#define _particle_billboard_type_screen_horizontal		5
#define _particle_billboard_type_local_vertical			6
#define _particle_billboard_type_local_horizontal		7
#define _particle_billboard_type_world					8
#define _particle_billboard_type_velocity_horizontal	9

// Return the billboard basic in world space.
// The z-direction needs to point towards the camera for backface culling.
float3x3 billboard_basis(float3 position, float3 velocity, bool limited)
{
	int type= (int)g_render_state.m_billboard_type;
	float3x3 basis;
	if (type== _particle_billboard_type_screen_facing)
	{
		// basis is the x- and y- screen vectors
		basis[0]= Camera_Right;
		basis[1]= Camera_Up;
	}
	else if (type== _particle_billboard_type_camera_facing)
	{
		// basis which doesn't change with camera rotation
		float3 eye= normalize(position - Camera_Position);
		float3 perpendicular= (abs(eye.z) < 0.99f) ? float3(0, 0, 1) : float3(1, 0, 0);
		basis[0]= normalize(cross(eye, perpendicular));
		basis[1]= normalize(cross(basis[0], eye));
	}
	else if (!limited && (type== _particle_billboard_type_screen_parallel))
	{
		// basis contains velocity vector, and attempts to face screen
		basis[0]= normalize(velocity);
		basis[1]= normalize(cross(basis[0], position - Camera_Position));
	}
	else if (!limited && (type== _particle_billboard_type_screen_perpendicular))
	{
		// basis is perpendicular to the particle velocity
		float3 motion= normalize(velocity);
		float3 perpendicular= (abs(motion.z) < 0.99f) ? float3(0, 0, 1) : float3(1, 0, 0);
		basis[0]= normalize(cross(motion, perpendicular));
		basis[1]= cross(motion, basis[0]);	// already normalized
	}
	else if (!limited && (type== _particle_billboard_type_screen_vertical))
	{
		// basis has local-space vertical vector, and a perpendicular vector in screen space
		basis[0]= float3(0.0f, 0.0f, 1.0f);
		basis[1]= normalize(cross(basis[0], position - Camera_Position));	// could be simplified
	}
	else if (!limited && (type== _particle_billboard_type_screen_horizontal))
	{
		// basis is the local-space horizonal plane xy-basis
		basis[0]= float3(1.0f, 0.0f, 0.0f);
		basis[1]= float3(0.0f, 1.0f, 0.0f);
	}
	else if (!limited && (type== _particle_billboard_type_local_vertical))
	{
		// basis has local-space vertical vector, and a perpendicular vector in screen space
		basis[0]= float3(local_to_world[0][2], local_to_world[1][2], local_to_world[2][2]);
		basis[1]= normalize(cross(basis[0], position - Camera_Position));	// could be simplified
	}
	else if (!limited && (type== _particle_billboard_type_local_horizontal))
	{
		// basis is the local-space horizonal plane xy-basis
		basis[0]= float3(local_to_world[0][0], local_to_world[1][0], local_to_world[2][0]);
		basis[1]= float3(local_to_world[0][1], local_to_world[1][1], local_to_world[2][1]);
	}
	else if (!limited && (type== _particle_billboard_type_velocity_horizontal))
	{
		// basis contains velocity vector, and attempts to sit in the horizontal plane
		basis[0]= normalize(velocity);
		float3 perpendicular= (abs(basis[0].x) < 0.99f) ? float3(1, 0, 0) : float3(0, 0, 1);
		basis[1]= normalize(cross(perpendicular, basis[0]));
	}
	else // if (type== _particle_billboard_type_world)
	{
		// basis is world space
		basis[0]= float3(1.0f, 0.0f, 0.0f);
		basis[1]= float3(0.0f, 1.0f, 0.0f);
	}
	basis[2]= cross(basis[0], basis[1]);
	return basis;
}

float2 safe_normalize(float2 v)
{
	float norm= length(v);
	return (norm?(v/norm):v);
}

float3x3 matrix3x3_rotation_from_axis_and_angle(float3 axis, float angle)
{
	float3x3 mat;
	float2 sine_cosine;
	sincos(angle, sine_cosine.x, sine_cosine.y);
	float3 one_minus_cosine_times_axis= (1.0f-sine_cosine.yyy)*axis;

	//axis= normalize(axis);	//assume normalized

	mat[0]= one_minus_cosine_times_axis*axis.xxx + sine_cosine.yxx*float3(1.0f, axis.z, -axis.y);
	mat[1]= one_minus_cosine_times_axis*axis.yyy + sine_cosine.xyx*float3(-axis.z, 1.0f, axis.x);
	mat[2]= one_minus_cosine_times_axis*axis.zzz + sine_cosine.xxy*float3(axis.y, -axis.x, 1.0f);

	return mat;
}

// Generate the tangent/binormal/normal at a billboard corner, based on the simulated shape
// of the particle.  Curvature of 1.0f means the vertex normal is bent out sideways, into the
// plane of the billboard.  We can only actually support up to but not including 1.0f, or else
// interpolation will fail.
float3x3 surface_basis(float2x3 plane_basis, float2 plane_offset, float curvature)
{
	float3x3 basis;

	// This is the flat billboard basis
	basis[0]= plane_basis[0];				// tangent
	basis[1]= plane_basis[1];				// binormal
	basis[2]= cross(basis[0], basis[1]);	// normal

	plane_offset= safe_normalize(plane_offset);
	curvature*= _pi/2.0f;	// 1.0 means emulate a hemisphere, 0.0 means leave flat
	if (IS_DISTORTION_PARTICLE)
	{
		float3 rotation_axis= mul(float2(-plane_offset.y, plane_offset.x), plane_basis);
		float3x3 rotation_matrix= matrix3x3_rotation_from_axis_and_angle(rotation_axis, curvature);
		return mul(basis, rotation_matrix);
	}
	else
	{
		basis[2]+= normalize(tan(curvature)*mul(plane_offset, plane_basis));
		return basis;	// The normalize is wasted here, since we need to renormalize after interpolation
	}
}

// Most of this clutter is just for the smoke experiment...
float2 frame_texcoord(s_sprite_frame_definition frame, float2 vertex_uv, float2 scroll, float scale)
{
	frame.m_sprite_frame_uv.xy+= 0.5*(1.0f-scale)*frame.m_sprite_frame_uv.zw;
	return vertex_uv*frame.m_sprite_frame_uv.zw*scale + scroll*abs(frame.m_sprite_frame_uv.zw) + frame.m_sprite_frame_uv.xy;
}

float compute_variant(float input, int count, bool one_shot, bool backwards)
{
	if (count== 1)
	{
		return 0;
	}
	else
	{
		if (one_shot)
		{
			count-= 1;
		}
		float variant= count * input;
		if (backwards)
		{
			variant= count - variant;
		}
		return variant;
	}
}
#endif	//#ifndef pc

bool deform_particle(void)
{
	return false;	// not particle model
}

bool deform_particle_model(void)
{
	return true;	// is particle model
}


// Actual input vertex format is hard-coded in vfetches as s_particle_render_vertex_in
s_particle_interpolators default_vs(
#if DX_VERSION == 11
	in uint instance_id : SV_InstanceID,
	in uint vertex_id : SV_VertexID
#else
	vertex_type IN
#endif
	)
{
#if DX_VERSION == 11
	#if IS_VERTEX_TYPE(s_particle_vertex)
		uint quad_index = (vertex_id ^ ((vertex_id & 2) >> 1));

		s_particle_vertex IN;
		IN.index = (instance_id * 4) + quad_index + particle_index_range.x;
		IN.address = 0;
	#elif IS_VERTEX_TYPE(s_particle_model_vertex)
		s_particle_vertex IN;
		IN.index = (instance_id * particle_index_range.y) + vertex_id + particle_index_range.x;
	#endif
#endif

	s_particle_render_vertex OUT;
#ifdef PARTICLE_DEBUG_VAR
	OUT.m_debug_var= 0.0f;
#endif

#if !defined(pc) || (DX_VERSION == 11)

	// This would be used for killing verts by setting oPts.z!=0 .
	//asm {
	//	config VsExportMode=kill
	//};


	// Break the input index into a instance index and a vert index within the primitive.
	int instance_index = round((IN.index + 0.5f)/ g_render_state.m_vertex_count - 0.5f);	// This calculation is approximate (hence the 'round')
	int vertex_index = IN.index - instance_index * g_render_state.m_vertex_count;	// This calculation is exact

	s_particle_state STATE = read_particle_state(instance_index);

	//float pre_evaluated_scalar[_index_max]= preevaluate_particle_functions(STATE);

	// Kill timed-out particles...
	// Should be using oPts.z kill, but that's hard to do in hlsl.
	// XDS says equivalent to set position to NaN?
	if (STATE.m_age >= 1.0f || STATE.m_color.w== 0.0f)	// early out if particle is dead or transparent.
	{
		OUT.m_position.xyzw = hidden_from_compiler.xxxx;	// NaN
		OUT.m_texcoord_sprite0 = float2(0.0f, 0.0f);
		OUT.m_texcoord_sprite1 = float2(0.0f, 0.0f);
		OUT.m_texcoord_billboard = float2(0.0f, 0.0f);
		OUT.m_frame_blend = 0.0f;
		OUT.m_black_point = 0.0f;
		OUT.m_palette = 0.0f;
		OUT.m_color= float4(0.0f, 0.0f, 0.0f, 0.0f);
		OUT.m_color_add= float3(0.0f, 0.0f, 0.0f);
		OUT.m_binormal= float3(0.0f, 0.0f, 0.0f);
		OUT.m_tangent= float3(0.0f, 0.0f, 0.0f);
		OUT.m_normal= float3(0.0f, 0.0f, 0.0f);
		OUT.m_depth= 0.0f;
	}
	else
	{
		// Precompute rotation value
		float rotation= STATE.m_physical_rotation + STATE.m_manual_rotation;
		if (TEST_BIT(g_render_state.m_appearance_flags,_source_bitmap_vertical_bit))	// doesn't work for particle models.
		{
			rotation+= 0.25f;
		}

		// Compute vertex inputs which depend whether we are a billboard or a mesh particle
		float4x2 shift = {	{g_render_state.custom_vertex_0.x, g_render_state.custom_vertex_0.y},
							{g_render_state.custom_vertex_0.z, g_render_state.custom_vertex_0.w},
							{g_render_state.custom_vertex_1.x, g_render_state.custom_vertex_1.y},
							{g_render_state.custom_vertex_1.z, g_render_state.custom_vertex_1.w}, };
		float3 vertex_pos;
		float2 vertex_uv;
		float3 vertex_normal;
		float3x3 vertex_orientation;

		// Hack alert.  The "hidden_from_compiler.y" function is the only way to get a dependency on the vertex type.
		// We need to make the following be a compile-time branch; otherwise it impacts performance.
		// but we can't, because we always setting shader constants for default vertex type

#if DX_VERSION == 9
		bool IS_PARTICLE_MODEL= (hidden_from_compiler.y != 0);
		if (IS_PARTICLE_MODEL)
#elif IS_VERTEX_TYPE(s_particle_model_vertex)
		bool IS_PARTICLE_MODEL = true;
#else
		bool IS_PARTICLE_MODEL = false;
#endif
#if (DX_VERSION == 9) || (IS_VERTEX_TYPE(s_particle_model_vertex))
		{
			float variant= compute_variant(STATE.m_animated_frame + STATE.m_manual_frame, g_all_mesh_variants.m_mesh_variant_count,
				TEST_BIT(g_render_state.m_animation_flags,_frame_animation_one_shot_bit),
				TEST_BIT(g_render_state.m_animation_flags,_can_animate_backwards_bit) && TEST_BIT(256*STATE.m_random.z,0));
			int variant_index0= floor(variant%g_all_mesh_variants.m_mesh_variant_count);

			float4 pos_sample;
			float4 uv_sample;
			float4 normal_sample;
			vertex_index= min(vertex_index, g_all_mesh_variants.m_mesh_variants[variant_index0].m_mesh_variant_end_index -
											g_all_mesh_variants.m_mesh_variants[variant_index0].m_mesh_variant_start_index);
			vertex_index+= g_all_mesh_variants.m_mesh_variants[variant_index0].m_mesh_variant_start_index;

#ifdef XENON
			asm {
				vfetch pos_sample, vertex_index, position
				vfetch uv_sample, vertex_index, texcoord
				vfetch normal_sample, vertex_index, normal
			};
#elif DX_VERSION == 11
			uint offset = vertex_index * 20;

			pos_sample = UnpackUShort4N(mesh_vertices.Load2(offset));
			uv_sample = UnpackUShort2N(mesh_vertices.Load(offset + 8)).xyxy;
			normal_sample = UnpackHalf4(mesh_vertices.Load2(offset + 12));
#endif

			vertex_pos= pos_sample.xyz * Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;

			vertex_uv= uv_sample.xy * UV_Compression_Scale_Offset.xy + UV_Compression_Scale_Offset.zw;
			vertex_normal= normal_sample.xyz;
			vertex_orientation= matrix3x3_rotation_from_axis_and_angle(STATE.m_axis, _2pi*rotation);
		}
#endif
#if DX_VERSION == 9
		else
#endif
#if (DX_VERSION == 9) || (IS_VERTEX_TYPE(s_particle_vertex))
		{
			vertex_pos= float3(shift[vertex_index] * g_sprite.m_corner.zw + g_sprite.m_corner.xy, 0.0f);
			vertex_uv= shift[vertex_index];
			vertex_normal= float3(0.0f, 0.0f, 1.0f);

			float rotsin, rotcos;
			sincos(_2pi*rotation, rotsin, rotcos);
			vertex_orientation= float3x3(float3(rotcos, rotsin, 0.0f), float3(-rotsin, rotcos, 0.0f), float3(0.0f, 0.0f, 1.0f));
		}
#endif

		// Transform from local space to world space
		float3 position= mul(local_to_world, float4(STATE.m_position, 1.0f));
		float3 velocity= mul((float3x3)local_to_world, STATE.m_velocity);

		// Compute the vertex position within the plane of the sprite
		float3 planar_pos= vertex_pos;
		float particle_scale= STATE.m_size;
		float3 relative_velocity= velocity;
		float aspect= STATE.m_aspect;
		if (TEST_BIT(g_render_state.m_appearance_flags,_motion_blur_bit))
		{
			float frame_rate= 30.f;	// just a baseline --- should not reflect actual frame rate
			relative_velocity-= g_motion_blur_state.m_observer_velocity;
			float3 eye= position - Camera_Position;
			relative_velocity-= cross(position - Camera_Position, g_motion_blur_state.m_observer_rotation) / dot(eye, eye);
			aspect+= length(relative_velocity) * g_motion_blur_state.m_motion_blur_aspect_scale / (frame_rate * particle_scale);
		}
		planar_pos.x*= aspect;

		// Transform from sprite plane to world space.
		float3x3 plane_basis= mul(vertex_orientation, billboard_basis(position, relative_velocity, false));	// in world space
		float3x3 vertex_basis= (TEST_CATEGORY_OPTION(lighting,per_pixel_smooth) || TEST_CATEGORY_OPTION(lighting,smoke_lighting) || IS_DISTORTION_PARTICLE)
			? surface_basis(plane_basis, planar_pos, g_render_state.m_curvature)
			: plane_basis;

		// We fade out particles near camera in order to save on fill rate. Previously, this was done by computing linear depth wrt camera
		// based on particle corner position. This causes some of the particle polygon's vertices to be set to NaN and the entire triangle
		// often got clipped resulting in partially clipped particles (very visibly noticeable).
		// A better and more robust method is to use the particle center to determine whether the entire particle needs to be faded out near
		// camera. This ensures that all four corners will use identical depth, and that none of the vertices' positions will be set to NaN.
		// This lets the rasterizer do its job and properly clip the particle to viewport, yet fade it out when it's within the cutoff range.
		// As such, compute particle depth (distance to camera) based on the particle center position here: (natashat)
		float depth= dot(Camera_Backward, Camera_Position-position.xyz);

		position.xyz += mul(planar_pos, plane_basis) * particle_scale;

		// Transform from world space to clip space.
		OUT.m_position= mul(float4(position, 1.0f), View_Projection);

		// Particle depth for pixel shader (used for depth-based fadeout color) is computed based on particle corner position (correctly):
		OUT.m_depth= dot(Camera_Backward, Camera_Position-position.xyz);

		if (IS_DISTORTION_PARTICLE)
		{
			// For distortion, these are in view space; for lighting in world space.
			vertex_basis[0]= mul(float3x3(Camera_Right, Camera_Up, -Camera_Backward), vertex_basis[0])
				* particle_scale * g_sprite.m_corner.z;
			vertex_basis[1]= mul(float3x3(Camera_Right, Camera_Up, -Camera_Backward), vertex_basis[1])
				* particle_scale * g_sprite.m_corner.w;
		}
		OUT.m_normal= mul(vertex_normal, vertex_basis);	// corresponds to vertex normal
		if (IS_DISTORTION_PARTICLE)
		{
			OUT.m_tangent = vertex_basis[0];	// corresponds to direction of increasing u
			OUT.m_binormal= vertex_basis[1];	// corresponds to direction of increasing v
		}
		else
		{
			OUT.m_tangent= float3(0.0f, 0.0f, 0.0f);
			OUT.m_binormal= float3(0.0f, 0.0f, 0.0f);
		}
		// Compute vertex texcoord
		if (TEST_BIT(g_render_state.m_appearance_flags,_randomly_flip_u_bit) && TEST_BIT(256*STATE.m_random.x,0))
		{
			vertex_uv.x= 1-vertex_uv.x;
		}
		if (TEST_BIT(g_render_state.m_appearance_flags,_randomly_flip_v_bit) && TEST_BIT(256*STATE.m_random.y,0))
		{
			vertex_uv.y= 1-vertex_uv.y;
		}
		OUT.m_texcoord_billboard= vertex_uv;
		float2 uv_scroll= g_render_state.m_uv_scroll_rate * g_render_state.m_game_time;
		float uv_scale0= 1.0f;
		float uv_scale1= 1.0f;

		float frame= compute_variant(STATE.m_animated_frame + STATE.m_manual_frame, g_all_sprite_frames.m_sprite_frame_count,
			TEST_BIT(g_render_state.m_animation_flags,_frame_animation_one_shot_bit),
			TEST_BIT(g_render_state.m_animation_flags,_can_animate_backwards_bit) && TEST_BIT(256*STATE.m_random.z,0));
		int frame_index0= floor(frame%g_all_sprite_frames.m_sprite_frame_count);

		IF_CATEGORY_OPTION(frame_blend, off)
		{
			OUT.m_frame_blend= 0;
		}
		else
		{
			OUT.m_frame_blend= frac(frame);
			uv_scale0= 1.0f/lerp(starting_uv_scale, ending_uv_scale, (1.0f + OUT.m_frame_blend)/2.0f);
			uv_scale1= 1.0f/lerp(starting_uv_scale, ending_uv_scale, (0.0f + OUT.m_frame_blend)/2.0f);
		}

		OUT.m_texcoord_sprite1= float2(0, 0);
		if (DOUBLE_SPRITE_TEXCOORD)
		{
			int frame_offset= 1;
			IF_CATEGORY_OPTION(frame_blend, off)
			{
				frame_offset= floor(STATE.m_random.x*16);
			}
			int frame_index1= (frame_index0+frame_offset)%g_all_sprite_frames.m_sprite_frame_count;
			OUT.m_texcoord_sprite1= frame_texcoord(g_all_sprite_frames.m_sprite_frames[frame_index1], vertex_uv, uv_scroll, uv_scale1);
		}

		OUT.m_texcoord_sprite0= frame_texcoord(g_all_sprite_frames.m_sprite_frames[frame_index0], vertex_uv, uv_scroll, uv_scale0);

		// Compute particle color
		OUT.m_color.xyz= STATE.m_color.xyz * STATE.m_initial_color.xyz * STATE.m_intensity * exp2(STATE.m_initial_color.w);
		OUT.m_color_add.xyz= 0.0f;
		IF_CATEGORY_OPTION(blend_mode, multiply)
		{
		}
		else if (BLEND_MODE_SELF_ILLUM)
		{
			OUT.m_color.xyz*= V_ILLUM_EXPOSURE;
		}
		else
		{
			OUT.m_color.xyz*= v_exposure.x;
		}
		IF_CATEGORY_OPTION(self_illumination, constant_color)
		{
			OUT.m_color_add.xyz+= self_illum_color.xyz * V_ILLUM_EXPOSURE;
		}
#ifdef SCOPE_TRANSPARENTS
		IF_CATEGORY_OPTION(fog, on)	// fog
		{
			float3 inscatter;
			float extinction;
			compute_scattering(Camera_Position, position.xyz, inscatter, extinction);
			OUT.m_color.xyz*= extinction;
			OUT.m_color_add.xyz+= inscatter * v_exposure.x;
		}
#endif // SCOPE_TRANSPARENTS
		IF_CATEGORY_OPTION(lighting, per_vertex_ambient)
		{
			OUT.m_color.xyz *= v_lighting_constant_3.rgb;
		}

		// Compute particle alpha
		OUT.m_color.w= STATE.m_color.w;

		if (TEST_BIT(g_render_state.m_appearance_flags,_intensity_affects_alpha_bit))
		{
			OUT.m_color.w*= STATE.m_intensity;
		}
		if (/* TEST_BIT(g_render_state.m_appearance_flags,_fade_near_camera_bit) && */	// always on now
			!g_render_state.m_first_person)
		{
			OUT.m_color.w*= saturate(g_render_state.m_near_range * (depth - g_render_state.m_near_cutoff));
		}
		if (TEST_BIT(g_render_state.m_appearance_flags,_fade_near_edge_bit))
		{
			// Fade to transparent when billboard is edge-on ... but independent of camera orientation
			float3 camera_to_vertex= normalize(position.xyz-Camera_Position);
			float billboard_angle= k_half_pi-acos(abs(dot(camera_to_vertex, OUT.m_normal)));
			OUT.m_color.w*= saturate(g_render_state.m_edge_range * (billboard_angle - g_render_state.m_edge_cutoff));
		}
		OUT.m_black_point= saturate(STATE.m_black_point);
		OUT.m_palette= TEST_CATEGORY_OPTION(albedo, diffuse_only)
			? 0.0f
			: frac(STATE.m_palette_v);

		// extra kill test ... not strictly correct since other verts in the quad might be alive
		if (OUT.m_color.w== 0.0f && !IS_PARTICLE_MODEL)
		{
			OUT.m_position.xyzw = hidden_from_compiler.xxxx;	// NaN
		}
   }
#else	//#ifndef pc
	OUT.m_position= float4(0.0f, 0.0f, 0.0f, 0.0f);	// Doesn't work on PC!!!  (This just makes it compile.)
	OUT.m_color= float4(0.0f, 0.0f, 0.0f, 0.0f);	// Doesn't work on PC!!!  (This just makes it compile.)
	OUT.m_color_add= float3(0.0f, 0.0f, 0.0f);
	OUT.m_texcoord_sprite0 = float2(0.0f, 0.0f);
	OUT.m_texcoord_sprite1 = float2(0.0f, 0.0f);
	OUT.m_texcoord_billboard = float2(0.0f, 0.0f);
	OUT.m_frame_blend = 0.0f;
	OUT.m_black_point = 0.0f;
	OUT.m_palette = 0.0f;
	OUT.m_normal= float3(0.0f, 0.0f, 0.0f);
	OUT.m_binormal= float3(0.0f, 0.0f, 0.0f);
	OUT.m_tangent= float3(0.0f, 0.0f, 0.0f);
	OUT.m_depth= 0.0f;
#endif	//#ifndef pc #else

    return write_particle_interpolators(OUT);
}

#endif	//#ifdef VERTEX_SHADER

#ifdef PIXEL_SHADER
// Specialized routine for smoothly fading out particles.  Maps
//		[0, black_point] to 0
//		[black_point, mid_point] to [0, mid_point] linearly
//		[mid_point, 1] to [mid_point, 1] by identity
// where mid_point is halfway between black_point and 1
//
//		|                   **
//		|                 **
//		|               **
//		|             **
//		|            *
//		|           *
//		|          *
//		|         *
//		|        *
//		|       *
//		|*******_____________
//      0      bp    mp      1
float remap_alpha(float black_point, float alpha)
{
	float mid_point= (black_point+1.0f)/2.0f;
	return mid_point*saturate((alpha-black_point)/(mid_point-black_point))
		+ saturate(alpha-mid_point);	// faster than a branch
}

// define before render_target.fx
#if TEST_CATEGORY_OPTION(render_targets, ldr_only)
#define LDR_ONLY 1
#endif

// $TODO:  saves a little ALU...
//#define LDR_gamma2 false
//#define HDR_gamma2 false

#include "shared\utilities.fx"
#include "shared\render_target.fx"

#if !defined(pc) || (DX_VERSION == 11)
// Taken out for now
#define normal_map_as_base_map false
#define lightmap_lighting false

PARAM(float3, screen_constants);
PARAM(float, distortion_scale);

PARAM_SAMPLER_2D(base_map);
PARAM(float4, base_map_xform);

PARAM_SAMPLER_2D(base_map2);
PARAM(float4, base_map2_xform);

PARAM_SAMPLER_2D(palette);
PARAM_SAMPLER_2D(alpha_map);

PARAM(float3, tint_color);
PARAM(float, modulation_factor);
PARAM(float, alpha_modulation_factor);

PARAM(float, palette_shift_amount);

PARAM(float, sphere_warp_scale);

float2 calc_warp(float2 texcoord_billboard)
{
	IF_CATEGORY_OPTION(warp,	sphere)
	{
		// sphere warp sprite, based on billboard
		float2 delta= texcoord_billboard * 2 - 1;			/// [-1, 1] across sprite

		float delta2=		dot(delta.xy, delta.xy);
		float delta4=		delta2 * delta2;

//		better approximation, but more expensive:
//		float delta6=		delta2 * delta2 * delta2;
//		float delta_offset=		delta2 * 0.05f + delta6 * 0.37f;				// ###ctchou $TODO we could give artists control of this polynomial if they want..  maybe default it to the sphere control, but let them do whatever..

		// we don't need to calculate delta, since it cancels itself out.  save the sqrt, save the world!
		float delta_offset=		delta4 * sphere_warp_scale;						// decent approximation of a sphere

		float2 offset=			delta.xy * delta_offset;

		return offset;
	}
	else
	{
		return float2(0.0f, 0.0f);
	}
}

float3 calculate_lighting_ps(float3 normal)
{
	IF_CATEGORY_OPTION(lighting, per_pixel_smooth)
	{
		float cosine=	dot(normal.xyz, p_lighting_constant_0.xyz);
		float biased=	saturate(cosine * contrast_scale + contrast_offset);
		float blend=	biased*biased*biased;
		return lerp(p_lighting_constant_2.rgb, p_lighting_constant_1.rgb, blend);
	}

	// default unlit
	return float3(1.0f, 1.0f, 1.0f);
}

float4 sample_diffuse(float2 texcoord_sprite, float2 texcoord_other_sprite, float2 texcoord_billboard, float palette_v, float particle_alpha, float depth_alpha)
{
	IF_CATEGORY_OPTION(albedo, diffuse_only)
	{
		return sample2D(base_map, texcoord_sprite);
	}

	IF_CATEGORY_OPTION(albedo, diffuse_modulated)
	{
		float4 diffuse= sample2D(base_map, texcoord_sprite);
		float Y= dot(diffuse.rgb, diffuse.rgb) / sqrt(3.0f);
		diffuse.xyz *= lerp(tint_color, 1.0f, modulation_factor * Y);
		return diffuse;
	}

	IF_CATEGORY_OPTION(albedo, palettized_glow)
	{
		float ramp= sample2D(base_map, texcoord_sprite).g;
		float glow= palette_v * ramp;
		float4 diffuse= float4(saturate(tint_color.rgb * glow * exp2(glow * 6)), ramp);
		return diffuse;
	}

	IF_CATEGORY_OPTION(albedo, diffuse_plus_billboard_alpha)
	{
		return float4(sample2D(base_map, texcoord_sprite).xyz, sample2D(alpha_map, texcoord_billboard).w);
	}

	IF_CATEGORY_OPTION(albedo, diffuse_plus_sprite_alpha)
	{
		return float4(sample2D(base_map, texcoord_sprite).xyz, sample2D(alpha_map, texcoord_sprite).w);
	}

	// Dependent texture fetch.  The palette can be any size.  In order to avoid filtering artifacts,
	// the palette should be smoothly varying, or else filtering should be turned off.
	IF_CATEGORY_OPTION(albedo, palettized)
	{
		float index= sample2D(base_map, texcoord_sprite).x;

		IF_CATEGORY_OPTION(depth_fade, palette_shift)
		{
			index=	saturate(index + (1-depth_alpha*particle_alpha) * palette_shift_amount);
		}

		return sample2D(palette, float2(index, palette_v));
	}

	// Same as above except the alpha comes from the original texture, not the palette.
	IF_CATEGORY_OPTION(albedo, palettized_plus_billboard_alpha)
	{
		float index= sample2D(base_map, texcoord_sprite).x;
		float alpha= sample2D(alpha_map, texcoord_billboard).w;

		IF_CATEGORY_OPTION(depth_fade, palette_shift)
		{
			index=	saturate(index + (1-depth_alpha*particle_alpha) * palette_shift_amount);
		}

		return float4(sample2D(palette, float2(index, palette_v)).xyz, alpha);
	}

	IF_CATEGORY_OPTION(albedo, palettized_plus_sprite_alpha)
	{
		float index= sample2D(base_map, texcoord_sprite).x;
		float alpha= sample2D(alpha_map, texcoord_sprite).w;

		IF_CATEGORY_OPTION(depth_fade, palette_shift)
		{
			index=	saturate(index + (1-depth_alpha*particle_alpha) * palette_shift_amount);
		}

		return float4(sample2D(palette, float2(index, palette_v)).xyz, alpha);
	}

	IF_CATEGORY_OPTION(albedo, palettized_plasma)
	{
		float noise_a=	sample2D(base_map,	texcoord_sprite * base_map_xform.xy		+ base_map_xform.zw).r;
		float noise_b=	sample2D(base_map2,	texcoord_other_sprite * base_map2_xform.xy	+ base_map2_xform.zw).r;
		float index=	abs(noise_a - noise_b);

		float alpha=	sample2D(alpha_map, texcoord_billboard).a;

		index=	saturate(index + (1-alpha*particle_alpha*depth_alpha) * alpha_modulation_factor);

		float4 palette_value=	sample2D(palette, float2(index, palette_v));

		return float4(palette_value.rgb, alpha);
	}

	IF_CATEGORY_OPTION(albedo, palettized_2d_plasma)
	{
		float noise_a=	sample2D(base_map,	texcoord_sprite * base_map_xform.xy		+ base_map_xform.zw).r;
		float noise_b=	sample2D(base_map2,	texcoord_other_sprite * base_map2_xform.xy	+ base_map2_xform.zw).r;
		float index=	abs(noise_a - noise_b);

		float alpha=	sample2D(alpha_map, texcoord_billboard).a;

		IF_CATEGORY_OPTION(depth_fade, palette_shift)
		{
			index=	saturate(index + (1-alpha*particle_alpha) * palette_shift_amount);
		}

		float4 palette_value=	sample2D(palette, float2(index, depth_alpha));
//		float4 palette_value=	pow(1-abs(index - (1-depth_alpha)), 20);

		return float4(palette_value.rgb, alpha);
	}
}

float compute_depth_fade(float2 screen_coords, float depth, float range)
{
#if DX_VERSION != 11	// on D3D11/Durango we set the downscaled depth buffer as input
	if (TEST_CATEGORY_OPTION(depth_fade, low_res))
	{
		// get even/odd pixel
//		float2 odd_coords= frac(screen_coords * 0.5f) * 2.0f;

		// convert to hi-res depth, offset for the MSAA pixel reordering
//		screen_coords= screen_coords * depth_transform.xy - odd_coords;
		screen_coords= screen_coords * depth_transform.xy;

		float4 depth_value;
#ifdef xenon
		asm
		{
			tfetch2D depth_value.x___, screen_coords, depth_buffer, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled, OffsetX= +0.0, OffsetY= +0.0
			tfetch2D depth_value._x__, screen_coords, depth_buffer, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled, OffsetX= +1.0, OffsetY= +0.0
			tfetch2D depth_value.__x_, screen_coords, depth_buffer, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled, OffsetX= +0.0, OffsetY= +1.0
			tfetch2D depth_value.___x, screen_coords, depth_buffer, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled, OffsetX= +1.0, OffsetY= +1.0
		};
#elif DX_VERSION == 11
		depth_value.x= depth_buffer.Load(int3(screen_coords, 0));
		depth_value.y= depth_buffer.Load(int3(screen_coords, 0), uint2(1, 0));
		depth_value.z= depth_buffer.Load(int3(screen_coords, 0), uint2(0, 1));
		depth_value.w= depth_buffer.Load(int3(screen_coords, 0), uint2(1, 1));
#endif
		float4 scene_depth= 1.0f - depth_value.xyzw;
		scene_depth= 1.0f / (depth_constants.x + scene_depth * depth_constants.y);	// convert to real depth
		float4 particle_depth= depth;
		float4 delta_depth= scene_depth - particle_depth;
		return dot(saturate(delta_depth / range), float4(0.25f, 0.25f, 0.25f, 0.25f));
	}
	else
#endif
	{
#if DISTORTION_MULTISAMPLED
		if (IS_DISTORTION_PARTICLE)
		{
			screen_coords *= 2.0f;
		}
#endif

#if DX_VERSION == 11
		float scene_depth = 1.0f - depth_buffer.Load(int3(screen_coords.xy, 0)).x;
		scene_depth= 1.0f / (depth_constants.x + scene_depth * depth_constants.y);	// convert to real depth
#else
		float4 depth_value;
		asm
		{
			tfetch2D depth_value, screen_coords, depth_buffer, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled
		};
		float scene_depth= 1.0f - depth_value.x;
		scene_depth= 1.0f / (depth_constants.x + scene_depth * depth_constants.y);	// convert to real depth
#endif

		float particle_depth= depth;
		float delta_depth= scene_depth - particle_depth;
		return saturate(delta_depth / range);
	}
}

float2 compute_normalized_distortion(s_particle_render_vertex IN, float2 screen_coords, float2 blended, float depth_fade)
{
	// Fake a spherical distortion map
	//blended.xy= IN.m_texcoord_sprite0;
	//blended.xy-= float2(0.5f, 0.5f);
	//blended.xy= -blended.xy;
	//float dist_from_edge= saturate(0.5f - length(blended.xy));
	//blended.xy*= 2*dist_from_edge;

	// Fake a shift in the v-direction
	//blended.xy= float2(0.0f, 1.0f);

	blended.y= -blended.y;

	float2 displacement= blended.xy*screen_constants.z*IN.m_color.w*depth_fade;
	float2x2 billboard_basis= float2x2(IN.m_tangent.xy, IN.m_binormal.xy);
	float2 frame_displacement= mul(billboard_basis, displacement)/IN.m_depth;

	// At this point, displacement is in units of frame widths/heights.  I don't think pixel kill gains anything here.
	// We now require pixel kill for correctness, because we don't use depth test.
	clip(dot(frame_displacement, frame_displacement)==0.0f ? -1 : 1);

	// Now use full positive range of render target [0.0,32.0)
	float2 distortion= distortion_scale * frame_displacement;

	if (TEST_CATEGORY_OPTION(specialized_rendering, distortion_expensive))
	{
		static float fudge_scale= 1.0f;
		clip(compute_depth_fade(screen_coords + distortion * fudge_scale / 64.0f, IN.m_depth, 1.0f)== 0 ? -1 : 1);
	}

	static float max_displacement= 1.0f;	// if used, keep in sync with displacement.hlsl
	return distortion * screen_constants / max_displacement;
}
#endif	//#ifndef pc


typedef accum_pixel s_particle_render_pixel_out;
s_particle_render_pixel_out default_ps(
	s_particle_interpolators INTERPOLATORS,
	SCREEN_POSITION_INPUT(screen_coords))
{
#if !defined(pc) || (DX_VERSION == 11)
	s_particle_render_vertex IN= read_particle_interpolators(INTERPOLATORS);

	float depth_fade= ((TEST_CATEGORY_OPTION(depth_fade, on) || TEST_CATEGORY_OPTION(depth_fade, low_res) || TEST_CATEGORY_OPTION(depth_fade, palette_shift)) && !TEST_CATEGORY_OPTION(blend_mode, opaque))
		? compute_depth_fade(screen_coords, IN.m_depth, depth_fade_range)
		: 1.0f;

	float2 warp_offset=	calc_warp(IN.m_texcoord_billboard);

	float4 blended= TEST_CATEGORY_OPTION(frame_blend, on)
		? lerp(sample_diffuse(IN.m_texcoord_sprite0 + warp_offset, IN.m_texcoord_sprite1 + warp_offset, IN.m_texcoord_billboard, IN.m_palette, IN.m_color.a, depth_fade),
				sample_diffuse(IN.m_texcoord_sprite1 + warp_offset, IN.m_texcoord_sprite0 + warp_offset, IN.m_texcoord_billboard, IN.m_palette, IN.m_color.a, depth_fade), IN.m_frame_blend)
		: sample_diffuse(IN.m_texcoord_sprite0 + warp_offset, IN.m_texcoord_sprite1 + warp_offset, IN.m_texcoord_billboard, IN.m_palette, IN.m_color.a, depth_fade);

#ifdef PARTICLE_PIXEL_KILL	// probably not worth it, since you would need all pixels in a vector to die
	static float alpha_cutoff= 0.5f/255.0f;
	clip(IN.m_color.w*blended.w<alpha_cutoff ? -1 : 1);	// early out if sampled alpha is 0, only helps if all ALU threads take it
#endif

	if (IS_DISTORTION_PARTICLE)
	{

		float2 normalized_displacement= compute_normalized_distortion(IN, screen_coords, blended, depth_fade);
		accum_pixel distorted_pixel;
		distorted_pixel.color= float4(normalized_displacement, 0.0f, 1.0f);

#ifdef pc
		// On Xenon the distortion generation pass uses a D3DFMT_R16G16_EDRAM surface and the GPU does not
		// support blend modes involving the alpha channel in this mode.  Reach incorrectly uses alpha blend
		// modes involving SRCBLEND and the GPU ends up using the green channel instead of 1 as set above.
		// To emulate this bug we just output the green channel before scaling to alpha.
		distorted_pixel.color.a = distorted_pixel.color.g;
		distorted_pixel.color.rg = distorted_pixel.color.rg * 1024.0f / 32767.0f; // on PC use [0, 1] range instead [6/12/2012 paul.smirnov]
#endif

		return distorted_pixel;
	}
	else
	{
		//if (normal_map_as_base_map)
		//{
		//	blended.xyzw= saturate(blended.xxxy);
		//}

		blended.w*= depth_fade;

		IF_CATEGORY_OPTION(black_point, on)
		{
			blended.w= remap_alpha(IN.m_black_point, blended.w);
		}

		IF_CATEGORY_OPTION(lighting, smoke_lighting)
		{
		}
		else
		{
			blended*= IN.m_color;
		}

		IN.m_normal= normalize(IN.m_normal);	// I think cross is fewer instructions, with no interpolator

		blended.xyz *= calculate_lighting_ps(IN.m_normal);

		IF_CATEGORY_OPTION(lighting, smoke_lighting)
		{
#if !defined(pc) || (DX_VERSION == 11)
			float2 texcoord= IN.m_texcoord_billboard.xy;

			// convert uniform warp map into warped sphere normal:
			blended.xy= blended.xy * 2 - 1;
			blended.xy= (texcoord.xy * 2 - 1) * bump_contrast + blended.xy * bump_randomness;		// first scale factor affects contrast,  second scale factor affects randomness

			float4 gradients;		// dx/dh,  dx/dv,  dy/dh,  dy/dv
#ifdef xenon
			asm {
				getGradients gradients, texcoord, base_map
			};
#elif DX_VERSION == 11
			gradients= GetGradients(texcoord);
#endif

			gradients.xy= normalize(gradients.xy);
			gradients.zw= normalize(gradients.zw);

			blended.xy= gradients.xy * blended.x + gradients.zw * blended.y;
//			blended.z= sqrt(1.0f - dot(blended.xy, blended.xy));

			blended.xy= blended.xy * 0.5f + 0.5f;

			blended.a *= IN.m_color.a;
			blended.xyz *= blended.a;

#endif // !pc
		}

		// Non-linear blend modes don't work under the normal framework...
		IF_CATEGORY_OPTION(blend_mode, multiply)
		{
			blended.xyz= lerp(float3(1.0f, 1.0f, 1.0f), blended.xyz, blended.w);
		}
		else
		{
			blended.xyz+= IN.m_color_add;
		}
	}

#else	//#ifndef pc
	float4 blended= float4(0.0f, 0.0f, 0.0f, 0.0f);
#endif	//#ifndef pc #else

#if DX_VERSION == 11
	// Prevent negative numbers and other weirdness in the framebuffer on D3D11
	blended.a = saturate(blended.a);
#endif

	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(blended, false, false);
}
#endif	//#ifdef PIXEL_SHADER
