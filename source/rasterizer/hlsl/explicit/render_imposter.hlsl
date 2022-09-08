/*
RENDER_IMPOSTER.HLSL
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
04/12/2006 13:36 xwan
*/

//This comment causes the shader compiler to be invoked for certain vertex types and entry points
//@entry default
//@entry albedo
//@entry active_camo
//@generate object_imposter

#define SCOPE_MESH_DEFAULT
#define SCOPE_LIGHTING_OPAQUE
#include "hlsl_constant_globals.fx"
#include "shared\utilities.fx"
#include "shared\blend.fx"
#include "shared\albedo_pass.fx"
#include "templated\deform.fx"
#include "shared\render_target.fx"
#include "explicit\render_imposter_registers.fx"

// rename entry point of water passes
#define render_object_vs			default_vs
#define render_object_ps			default_ps
#define render_object_blend_vs		albedo_vs
#define render_object_blend_ps		albedo_ps
#define render_big_battle_object_vs		active_camo_vs
#define render_big_battle_object_ps		active_camo_ps

#define k_imposter_brightness_adjustment			k_ps_imposter_adjustment_constants.x

#define _big_battle_unit_vertex_budget			k_vs_big_battle_squad_constants.x
#define _big_battle_unit_vertex_range			k_vs_big_battle_squad_constants.y
#define _big_battle_squad_unit_start_index		k_vs_big_battle_squad_constants.z
#define _big_battle_squad_time_different		k_vs_big_battle_squad_constants.w

#define pi										3.14f
#define object_imposter_diffuse_scale			9.0f

#define IMPOSTER_CLOUD_SAMPLING
#include "templated\analytical_mask.fx"

#if !defined(pc) || (DX_VERSION == 11) /* implementation of xenon version */

// The following defines the protocol for passing interpolated data between vertex/pixel shaders
struct s_imposter_interpolators
{
	float4 position			:SV_Position0;
	float3 normal			:NORMAL0;
	float3 diffuse			:COLOR0;
	float3 ambient			:COLOR1;
	float4 specular_shininess		:COLOR2;
	float4 change_colors_of_diffuse		:TEXCOORD0;
	float4 change_colors_of_specular	:TEXCOORD1;
	float3 fragment_to_camera_world		:TEXCOORD2;
};

struct s_big_battle_interpolators
{
	float4 position						:SV_Position0;
	float3 normal						:NORMAL0;
	float3 diffuse						:COLOR0;
	float3 ambient						:COLOR1;
	float4 specular_shininess			:COLOR2;
	float3 fragment_to_camera_world		:TEXCOORD1;
	float3 position_ws					:TEXCOORD2;
};


#ifdef VERTEX_SHADER

s_imposter_interpolators render_object_vs(
	in s_object_imposter_vertex vertex)
{
	float4 local_to_world_transform[3]; // unused


	deform_object_imposter(vertex, local_to_world_transform);

	s_imposter_interpolators OUT;

	OUT.position= mul(float4(vertex.position.xyz, 1.f), View_Projection);
	OUT.normal= vertex.normal;

	// world space direction to eye/camera
	OUT.fragment_to_camera_world.rgb= Camera_Position-vertex.position;

	// out diffuse/ambient/change_colors
	OUT.diffuse= vertex.diffuse * vertex.diffuse;
	OUT.ambient= vertex.ambient * vertex.ambient;
	OUT.specular_shininess.rgb= vertex.specular_shininess.rgb * vertex.specular_shininess.rgb;
	OUT.specular_shininess.a= vertex.specular_shininess.a;

	OUT.change_colors_of_diffuse= vertex.change_colors_of_diffuse * vertex.change_colors_of_diffuse;
	OUT.change_colors_of_specular= vertex.change_colors_of_specular * vertex.change_colors_of_specular;

	return OUT;
}


s_big_battle_interpolators big_battle_object_vs(
	in float4 position,
	in float3 normal,
	in float3 diffuse,
	in float3 ambient,
	in float4 specular_shininess,
	in float4 unit_velocity,
	in float4 unit_position_scale,
	in float4 unit_foward,
	in float4 unit_left)
{
	float4 unit_up;
	unit_up.xyz= cross(unit_foward, unit_left);

	// decompress position
	position.xyz= position.xyz*Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;

	// transform position and normal to world space
	float3 new_position=
		unit_foward*position.x +
		unit_left*position.y +
		unit_up*position.z;
	new_position*= unit_position_scale.w;		// scale
	new_position+= unit_position_scale.xyz;		// offset
	new_position+= unit_velocity.xyz*_big_battle_squad_time_different;

	float3 new_normal=
		unit_foward*normal.x +
		unit_left*normal.y +
		unit_up*normal.z;

	// output data to pixel shader
	s_big_battle_interpolators OUT;
	{
		OUT.position= mul(float4(new_position.xyz, 1.f), View_Projection);
		OUT.normal= new_normal.xyz;

		OUT.diffuse= diffuse.rgb * diffuse.rgb;
		OUT.ambient= ambient.rgb * ambient.rgb;
		OUT.specular_shininess= specular_shininess;
		OUT.specular_shininess.rgb*= OUT.specular_shininess.rgb;
		OUT.fragment_to_camera_world= Camera_Position - new_position;
		OUT.position_ws= new_position;
	}

	return OUT;
}

#ifdef xenon
s_big_battle_interpolators render_big_battle_object_vs(
	in uint index: SV_VertexID)
{
	float unit_index= floor(index/_big_battle_unit_vertex_budget);
	float old_vertex_index= index - unit_index*_big_battle_unit_vertex_budget;
	float vertex_index= min(old_vertex_index, _big_battle_unit_vertex_range);


	// get vertex data
	float4 position, normal;
	float4 diffuse, ambient, specular_shininess;
#ifdef xenon
	// get vertex data
	asm
	{
		vfetch position, vertex_index, position0
		vfetch normal, vertex_index, normal0

		vfetch diffuse, vertex_index, texcoord1
		vfetch ambient, vertex_index, texcoord2
		vfetch specular_shininess, vertex_index, texcoord3
	};
#else
	position = 0;
	normal = 0;
	diffuse = 0;
	ambient = 0;
	specular_shininess = 0;
#endif

	// get unit data
	float4 unit_position_scale;
	float4 unit_foward, unit_left;
	float4 unit_velocity;

	unit_index+= _big_battle_squad_unit_start_index;
#ifdef xenon
	asm
	{
		vfetch unit_velocity, unit_index, tangent0
		vfetch unit_position_scale, unit_index, binormal0
		vfetch unit_foward, unit_index, color0
		vfetch unit_left, unit_index, color1

	};
#else
	unit_velocity = 0;
	unit_position_scale = 0;
	unit_foward = 0;
	unit_left = 0;
#endif

	s_big_battle_interpolators OUT= big_battle_object_vs(
		position,
		normal,
		diffuse,
		ambient,
		specular_shininess,
		unit_velocity,
		unit_position_scale,
		unit_foward,
		unit_left);

	if (old_vertex_index >= _big_battle_unit_vertex_range)
	{
		OUT.position= k_vs_hidden_from_compiler;
	}

	return OUT;
}
#else

s_big_battle_interpolators render_big_battle_object_vs(
	in s_object_imposter_vertex vertex,
	in s_big_battle_unit unit)
{
	return big_battle_object_vs(
		vertex.position,
		vertex.normal,
		vertex.diffuse,
		vertex.ambient,
		vertex.specular_shininess,
		unit.velocity,
		unit.position_scale,
		unit.forward,
		unit.left);
}
#endif

s_imposter_interpolators render_object_blend_vs(
	in s_object_imposter_vertex vertex)
{
	s_imposter_interpolators OUT= render_object_vs(vertex);
	return OUT;
}

#endif //VERTEX_SHADER


#ifdef PIXEL_SHADER

struct imposter_pixel
{
	float4 color : SV_Target0;			// albedo color (RGB) + specular mask (A)
	float4 normal : SV_Target1;			// normal (XYZ)
};


imposter_pixel convert_to_imposter_target(in float4 color, in float3 normal, in float normal_alpha_spec_type)
{
	imposter_pixel result;

	result.color= color;
	result.normal.xyz= normal * 0.5f + 0.5f;		// bias and offset to all positive
	result.normal.w= normal_alpha_spec_type;		// alpha channel for normal buffer (either blend factor, or specular type)

	return result;
}

#define pi 3.14159265358979323846
#define one_over_pi			0.32f

float imposter_convertBandwidth2TextureCoord(float fFandWidth)
{
    return fFandWidth;
}

float imposter_vmf_diffuse(in float4 Y[2],in float3 vSurfNormal_in)
{
    float2 dominant_coord=float2(dot(Y[0].xyz, vSurfNormal_in)*0.5+0.5,
        imposter_convertBandwidth2TextureCoord(Y[1].w));
	return sample2Dlod(k_ps_texture_vmf_diffuse,dominant_coord,0).a;
}

float3 imposter_dual_vmf_diffuse(float3 normal, float4 lighting_constants[4])
{
    float4 dom[2]={lighting_constants[0],lighting_constants[1]};
    float4 fil[2]={lighting_constants[2],lighting_constants[3]};
    float vmf_coeff_dom= imposter_vmf_diffuse(dom,normal);
    float vmf_coeff_fil= 0.25f;  // based on spherical harmonic or numerical integration

    float3 vmf_lighting=vmf_coeff_dom*
        lighting_constants[1].rgb+
        vmf_coeff_fil*
        lighting_constants[3].rgb;
    return vmf_lighting/pi;
}


float3 sample_reflect_cubemaps(
	in float3 reflect_dir)
{
	float4 reflection_0= sampleCUBE(k_ps_sampler_imposter_cubemap_0, reflect_dir);
	float4 reflection_1= sampleCUBE(k_ps_sampler_imposter_cubemap_1, reflect_dir);

	reflection_0.rgb= reflection_0.rgb * reflection_0.a;
	reflection_1.rgb= reflection_1.rgb * reflection_1.a;

	const float cubemap_blend_factor= k_ps_cubemap_constants.x;
	float3 reflect_color= lerp(reflection_0.rgb, reflection_1.rgb, cubemap_blend_factor);
	reflect_color*= 256;
	return reflect_color;
}

float3 calculate_change_color(
	const float4 coefficients)
{
	float3 out_color=
		(1.0f - coefficients.x + coefficients.x*k_ps_imposter_changing_color_0) *
		(1.0f - coefficients.y + coefficients.y*k_ps_imposter_changing_color_1) *
		(1.0f - coefficients.z + coefficients.z*k_ps_imposter_changing_color_2) *
		(1.0f - coefficients.w + coefficients.w*k_ps_imposter_changing_color_3);

	return out_color;
}

imposter_pixel render_object_ps( s_imposter_interpolators IN )
{
	float4 vmf_lighting_coefficients[4]= {
		p_vmf_lighting_constant_0,
		p_vmf_lighting_constant_1,
		p_vmf_lighting_constant_2,
		p_vmf_lighting_constant_3,
	};

	float3 view_dir= normalize(IN.fragment_to_camera_world);
	float3 normal= normalize(IN.normal);
	float n_dot_v= saturate(dot(normal, view_dir));

	float3 diffuse_radiance= imposter_dual_vmf_diffuse(normal, vmf_lighting_coefficients);

	float analytical_mask= get_analytical_mask(
		Camera_Position_PS - IN.fragment_to_camera_world,
		vmf_lighting_coefficients);

	float3 analytical_radiance=
		saturate(dot(k_ps_analytical_light_direction, normal)) *
		k_ps_analytical_light_intensity *
		vmf_lighting_coefficients[0].w / pi;
	float3 bounce_radiance= saturate(dot(k_ps_bounce_light_direction, normal))*k_ps_bounce_light_intensity/pi;
	diffuse_radiance+= analytical_mask * (analytical_radiance + bounce_radiance);

	float3 half_dir= normalize( k_ps_analytical_light_direction + view_dir );
	float n_dot_h= saturate(dot(normal, half_dir));

	// restore data
	const float4 diffuse_tints= IN.change_colors_of_diffuse;
	const float4 specular_tints= IN.change_colors_of_specular;

	const float shininess=
		IN.specular_shininess.w * 100;	// shininess

	// caculated diffuse and ambient
	const float3 diffuse=
		IN.diffuse *
		calculate_change_color(diffuse_tints);

	const float3 ambient= IN.ambient;

	const float3 specular=
		IN.specular_shininess.rgb *
		calculate_change_color(specular_tints);

	const float3 specular_radiance= k_ps_analytical_light_intensity * pow(n_dot_h, shininess);

	float4 out_color;
	out_color.rgb=
		specular*specular_radiance*analytical_mask +
		object_imposter_diffuse_scale*diffuse*diffuse_radiance +
		ambient;

	out_color.rgb*= k_imposter_brightness_adjustment;

	out_color.w= 0;

	// dim materials by wet
	out_color.rgb*= k_ps_wetness_coefficients.x;

	// apply exposure
	out_color.xyz= out_color.xyz * g_exposure.rrr;

	return convert_to_imposter_target(out_color, normal, 1.0);
}


float4 render_object_blend_ps(
	s_imposter_interpolators IN,
	in SCREEN_POSITION_INPUT(vpos)) :SV_Target0
{
	imposter_pixel OUT= render_object_ps(IN);


	float4 shadow;
#ifdef xenon
	asm {
		tfetch2D shadow, vpos, shadow_mask_texture, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled
	};
#else
	shadow = shadow_mask_texture.Load(int3(vpos.xy, 0));
#endif

	float alpha= k_ps_imposter_blend_alpha.a;
	float4 out_color;
	out_color.rgb= OUT.color.rgb * (1.0f - alpha) * shadow.a;
#ifdef xenon
	out_color.a= alpha * 0.03125f;	// scale by 1/32
#else
	out_color.a= alpha;
#endif
	return out_color;
}

imposter_pixel render_big_battle_object_ps(
	s_big_battle_interpolators IN) :SV_Target0
{
	float4 vmf_lighting_coefficients[4]= {
		p_vmf_lighting_constant_0,
		p_vmf_lighting_constant_1,
		p_vmf_lighting_constant_2,
		p_vmf_lighting_constant_3,
	};

	float3 view_dir= normalize(IN.fragment_to_camera_world);
	float3 normal= normalize(IN.normal);
	float n_dot_v= saturate(dot(normal, view_dir));

	float3 diffuse_radiance= imposter_dual_vmf_diffuse(normal, vmf_lighting_coefficients);

	float analytical_mask= get_analytical_mask(
		Camera_Position_PS - IN.fragment_to_camera_world,
		vmf_lighting_coefficients);

	float3 analytical_radiance=
		saturate(dot(k_ps_analytical_light_direction, normal)) *
		k_ps_analytical_light_intensity *
		vmf_lighting_coefficients[2].w / pi;
	float3 bounce_radiance= saturate(dot(k_ps_bounce_light_direction, normal))*k_ps_bounce_light_intensity/pi;
	diffuse_radiance+= analytical_mask * (analytical_radiance + bounce_radiance);

	float3 half_dir= normalize( k_ps_analytical_light_direction + view_dir );
	float n_dot_h= saturate(dot(normal, half_dir));

	const float shininess=
		IN.specular_shininess.w * 100;	// shininess

	// caculated diffuse and ambient
	const float3 diffuse= IN.diffuse;
	const float3 ambient= IN.ambient;
	const float3 specular= IN.specular_shininess.rgb;

	const float3 specular_radiance= k_ps_analytical_light_intensity * pow(n_dot_h, shininess);

	float4 out_color;
	out_color.rgb=
		specular*specular_radiance*analytical_mask +
		object_imposter_diffuse_scale*diffuse*diffuse_radiance +
		ambient;

	out_color.rgb*= k_imposter_brightness_adjustment;

	out_color.w= 0;

	// apply exposure
	out_color.xyz= out_color.xyz * g_exposure.rrr;

	return convert_to_imposter_target(out_color, normal, 1.0);
}


#endif //PIXEL_SHADER

#else /* implementation of pc version */

struct s_imposter_interpolators
{
	float4 position	:SV_Position0;
};

s_imposter_interpolators render_object_vs()
{
	s_imposter_interpolators OUT;
	OUT.position= 0.0f;
	return OUT;
}

float4 render_object_ps(s_imposter_interpolators IN) :SV_Target0
{
	return float4(0,1,2,3);
}

s_imposter_interpolators render_object_blend_vs()
{
	s_imposter_interpolators OUT;
	OUT.position= 0.0f;
	return OUT;
}

float4 render_object_blend_ps(s_imposter_interpolators IN) :SV_Target0
{
	return float4(0,1,2,3);
}

void render_big_battle_object_vs(
	in float4 position	:POSITION0,
	in float4 color		:TEXCOORD1,
	out float4 out_position	: SV_Position,
	out float3 out_color	: TEXCOORD0)
{
	const float3 unit_foward= k_vs_big_battle_squad_foward.xyz;
	const float3 unit_left= k_vs_big_battle_squad_left.xyz;
	const float3 unit_up= cross(unit_foward, unit_left);

	const float3 unit_position= k_vs_big_battle_squad_positon_scale.xyz;
	const float unit_scale= k_vs_big_battle_squad_positon_scale.w;

	const float3 unit_velocity= k_vs_big_battle_squad_velocity.xyz;

	//swizzle position for xenon data
	position.xyz= position.wzy;

	// decompress position
	position.xyz= position.xyz*Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;

	// transform position and normal to world space
	float3 new_position=
		unit_foward*position.x +
		unit_left*position.y +
		unit_up*position.z;

	new_position*= unit_scale;
	new_position+= unit_position;
	new_position+= unit_velocity.xyz*_big_battle_squad_time_different;

	out_position= mul(float4(new_position.xyz, 1.f), View_Projection);
	out_color= color.wzy;
}

float4 render_big_battle_object_ps(
	in float4 screen_position : SV_Position,
	in float3 color :TEXCOORD0) :SV_Target0
{
	return float4(color.rgb, 1);
}


#endif //pc/xenon

// end of rename marco
#undef render_object_vs
#undef render_object_ps
#undef IMPOSTER_CLOUD_SAMPLING