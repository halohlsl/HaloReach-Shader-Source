/*
RENDER_INSTANCE_IMPOSTER.HLSL
Copyright (c) Microsoft Corporation, 2008. all rights reserved.
ctchou
*/

//This comment causes the shader compiler to be invoked for certain vertex types and entry points
//@generate structure_instance_imposter
//@entry default
//@entry albedo

#define SCOPE_MESH_DEFAULT
#include "hlsl_constant_globals.fx"
#include "shared\utilities.fx"
#include "shared\atmosphere.fx"
#include "shared\blend.fx"
#include "shared\albedo_pass.fx"
#include "templated\velocity.fx"

#include "shared\render_target.fx"

// rename entry points
#define render_instance_polygon_vs			default_vs
#define render_instance_polygon_ps			default_ps
#define render_instance_card_vs			albedo_vs
#define render_instance_card_ps			albedo_ps


// reuse tessellation constants for changing color
#define k_vs_changing_color_0	k_vs_tessellation_parameter		
#define k_vs_changing_color_1	k_vs_hidden_from_compiler

#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#ifdef VERTEX_SHADER
	#define VERTEX_CONSTANT(type, name, register_index)   type name : register(c##register_index);
	#define PIXEL_CONSTANT(type, name, register_index)   type name;
#else
	#define VERTEX_CONSTANT(type, name, register_index)   type name;
	#define PIXEL_CONSTANT(type, name, register_index)   type name : register(c##register_index);
#endif
#define BOOL_CONSTANT(name, register_index)   bool name : register(b##register_index);
#define SAMPLER_CONSTANT(name, register_index)	sampler name : register(s##register_index);

SAMPLER_CONSTANT(k_ps_texture_vmf_diffuse, 0)
SAMPLER_CONSTANT(k_ps_texture_cloud, 1)

SAMPLER_CONSTANT(k_ps_texture_imposter_atlas, 2)
VERTEX_CONSTANT(float4, k_vs_atlas_tile_texcoord_scalar, 252)


#ifndef pc /* implementation of xenon version */


// The following defines the protocol for passing interpolated data between vertex/pixel shaders
struct s_imposter_card_interpolators
{
	float4 position						:	POSITION0;
	float4 color						:	COLOR0;
	float4 texcoord_and_hdr_scalar		:	TEXCOORD1;
	float4 fragment_to_camera_world		:	TEXCOORD2;
};

struct s_imposter_poly_interpolators
{
	float4 position						:	POSITION0;
	float4 color						:	COLOR0;
	float4 fragment_to_camera_world		:	TEXCOORD2;
};


struct s_imposter_vertex
{
    float4 position			:POSITION;
	float4 color			:COLOR0;
};



#ifdef VERTEX_SHADER


void deform_imposter(
	inout s_imposter_vertex vertex)
{	
	vertex.position=	vertex.position*Position_Compression_Scale.xyzw + Position_Compression_Offset.xyzw;
}


s_imposter_poly_interpolators render_instance_polygon_vs(
	in s_imposter_vertex vertex)
{
	deform_imposter(vertex);

	s_imposter_poly_interpolators OUT;

	OUT.position= mul(float4(vertex.position.xyz, 1.0f), View_Projection);

	// world space direction to eye/camera
	OUT.fragment_to_camera_world.xyz=	Camera_Position-vertex.position;	
//	OUT.fragment_to_camera_world.w=		dot(OUT.fragment_to_camera_world.xyz, Camera_Backward);
	OUT.fragment_to_camera_world.w=		sqrt(dot(OUT.fragment_to_camera_world.xyz, OUT.fragment_to_camera_world.xyz));

	OUT.color.rgb= vertex.color.rgb * exp2(vertex.color.a * 63.75 - 31.75);
	OUT.color.w= 0;

	return OUT;
}


s_imposter_card_interpolators render_instance_card_vs(
	in s_imposter_vertex vertex)
{
	deform_imposter(vertex);

	s_imposter_card_interpolators OUT;

	OUT.position= mul(float4(vertex.position.xyz, 1.0f), View_Projection);

	// world space direction to eye/camera
	OUT.fragment_to_camera_world.xyz= Camera_Position-vertex.position;	
	OUT.fragment_to_camera_world.w=		dot(OUT.fragment_to_camera_world.xyz, Camera_Backward);

	// caculated diffuse and ambient	
	OUT.color= 0;

	// each tile is 256x256. The tile index is packed in z channel of color
	float tile_index= floor(vertex.color.z*255 + 0.1f);
	float tile_y_index= floor((tile_index+0.1f) / 16);
	float tile_x_index= floor(tile_index - tile_y_index*16 + 0.1f);
	OUT.texcoord_and_hdr_scalar.xy= vertex.color.xy + float2(tile_x_index, tile_y_index);

	// scalar texcoords from tiles to the whole texture
	OUT.texcoord_and_hdr_scalar.xy*= k_vs_atlas_tile_texcoord_scalar.xy;
	OUT.texcoord_and_hdr_scalar.z= 0;
	OUT.texcoord_and_hdr_scalar.w= vertex.color.w * vertex.color.w * 128.0f; // refer to k_imposter_HDR_scale_range	

	return OUT;
}


#endif //VERTEX_SHADER


#ifdef PIXEL_SHADER

struct imposter_pixel
{
	float4 color : COLOR0;			// rgb, aa mask
	float4 normal : COLOR1;			// normal (XYZ), spec type
};


sampler2D unused_sampler;

float3 calc_normal_from_position(
	in float3 fragment_position_world)
{
#ifndef pc
	float4 gradient_horz, gradient_vert;
	
	// gradient_vert=	dx/dv, dy/dv, dx/dh, dy/dh
	// gradient_horz=	dz/dh, dz/dv, dz/dh, dz/dv
	asm {
		getGradients gradient_vert.ywxz, fragment_position_world.xy, unused_sampler
		getGradients gradient_horz.xyzw, fragment_position_world.zz, unused_sampler
	};

	gradient_horz.xy=	gradient_vert.zw;		// gradient_horz=	dx/dh, dy/dh, dz/dh, dz/dv
	gradient_vert.z=	gradient_horz.w;		// gradient_vert=	dx/dv, dy/dv, dz/dv, dy/dh

	float3 bump_normal=	normalize( -cross(gradient_horz.xyz, gradient_vert.xyz) );
	return bump_normal;
#else // PC
	float3 dBPx= ddx(fragment_position_world);		// worldspace gradient along pixel x direction
	float3 dBPy= ddy(fragment_position_world);		// worldspace gradient along pixel y direction
	float3 bump_normal= -normalize( cross(dBPx, dBPy) );	
	return bump_normal;
#endif // PC
}

float4 camera_normal_x : register(c150);
float4 camera_normal_y : register(c151);
float4 camera_normal_z : register(c152);

float3 calc_normal_from_camera_z(
	in float camera_z)					// camera_z is positive:	dot(fragment_position_world_space - camera_position_world_space, camera_forward_world_space)
{
	// the following code is based on constructing the surface gradient vectors
	// in the horizontal and vertical (h/v) directions in camera space
	// then using the cross product to get the normal in camera space:

	// pixel_proj_x=		(2 * tan(fov_x / 2) / pixels_x);
	// pixel_proj_y=		(2 * tan(fov_y / 2) / pixels_y);
	// grad_h=				{ camera_z * pixel_proj_x, 0.0f, ddx(camera_z) };
	// grad_v=				{ 0.0f, camera_z * pixel_proj_y, ddy(camera_z) };
	// normal_camera=		-cross(delta_h, delta_v);
	// normal_camera=		normalize(unnormal_camera);
	// normal_world=		normal_camera.x * Camera_Left + normal_camera.y * Camera_Up + normal_camera.z * Camera_Forward_;
	
	// we can optimize it by taking advantage of the zeros in the cross product, dividing out camera_z (which gets obliterated by the normalize), and then defining 3 constants:
	//
	// -cross(delta_h, delta_v)=	{	camera_z * ddx(camera_z) * pixel_proj_y,	camera_z * ddy(camera_z) * pixel_proj_x,	-camera_z * camera_z * pixel_proj_x * pixel_proj_y	}
	// -cross(delta_h, delta_v)=	camera_z * {	ddx(camera_z) * pixel_proj_y,	ddy(camera_z) * pixel_proj_x,	-camera_z * pixel_proj_x * pixel_proj_y	}
	//
	// camera_normal_x=		proj_y * camera_left
	// camera_normal_y=		proj_x * camera_up
	// camera_normal_z=		-proj_x * proj_y * camera_forward

	// NOTE : this is actually incorrect, as it doesn't account for the dx/dz and dy/dz components -- it assumes these are zero
	
	return	normalize(
				-ddx(camera_z)	* camera_z * normalize(camera_normal_x.xyz) * camera_normal_x.w +
				-ddy(camera_z)	* camera_z * normalize(camera_normal_y.xyz) * camera_normal_y.w +
				-camera_z		* camera_z * normalize(camera_normal_z.xyz) * camera_normal_z.w
			);
//			camera_z > 0 ? float3(-1.0f, 1.0f, -1.0f) : float3(1.0f, -1.0f, -1.0f);
//			float3(
//				ddx(camera_z) * 10.0f,
//				ddy(camera_z) * 10.0f,
//				camera_z * 0.1f);
}


imposter_pixel convert_to_imposter_target(in float4 color, in float3 normal, in float normal_alpha_spec_type)
{
	imposter_pixel result;
	
	result.color= color;
	result.normal.xyz= normal * 0.5f + 0.5f;		// bias and offset to all positive
	result.normal.w= normal_alpha_spec_type;		// alpha channel for normal buffer (either blend factor, or specular type)
	
	return result;
}

sampler2D non_cubemap_sampler : register(s0);


imposter_pixel render_instance_polygon_ps( s_imposter_poly_interpolators IN ) :COLOR0
{		
	float4 out_color;	
	out_color.rgb=	IN.color.rgb	*	k_ps_wetness_coefficients.y;

	out_color.a=	compute_antialias_blur_scalar_from_distance(IN.fragment_to_camera_world.w) * (1.0f / 32.0f);
	float3 normal=	calc_normal_from_position(IN.fragment_to_camera_world);

	return convert_to_imposter_target(out_color, normal, 1.0f);
}


imposter_pixel render_instance_card_ps( s_imposter_card_interpolators IN ) :COLOR0
{		
	float4 out_color= tex2D(k_ps_texture_imposter_atlas, IN.texcoord_and_hdr_scalar.xy);
	clip(out_color.a - 0.95f);

	// apply hdr scalar
	out_color.rgb	*= IN.texcoord_and_hdr_scalar.w;
	out_color.rgb	*= k_ps_wetness_coefficients.y;

	out_color.a=	compute_antialias_blur_scalar_from_distance(IN.fragment_to_camera_world.w) * (1.0f / 32.0f);
	float3 normal=	calc_normal_from_position(IN.fragment_to_camera_world);


	return convert_to_imposter_target(out_color, normal, 1.0f);
}


#endif //PIXEL_SHADER

#else /* implementation of pc version */

struct s_imposter_interpolators
{
	float4 position	:POSITION0;
};

s_imposter_interpolators render_instance_polygon_vs()
{
	s_imposter_interpolators OUT;
	OUT.position= 0.0f;
	return OUT;
}

float4 render_instance_polygon_ps(s_imposter_interpolators IN) :COLOR0
{
	return float4(0, 1, 2, 3);
}

s_imposter_interpolators render_instance_card_vs()
{
	s_imposter_interpolators OUT;
	OUT.position= 0.0f;
	return OUT;
}

float4 render_instance_card_ps(s_imposter_interpolators IN) :COLOR0
{
	return float4(0, 1, 2, 3);
}


#endif //pc/xenon

// end of rename marco
#undef render_instance_polygon_vs
#undef render_instance_polygon_ps
#undef render_instance_albedo_vs
#undef render_instance_albedo_ps
