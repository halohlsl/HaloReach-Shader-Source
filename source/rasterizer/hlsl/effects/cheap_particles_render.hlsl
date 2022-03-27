////#line 1 "source\rasterizer\hlsl\effects\cheap_particles_render.hlsl
//@generate tiny_position

#define VERTICES_PER_PARTICLE		4
#define PARTICLE_TEXTURE_WIDTH		128
#define PARTICLE_TEXTURE_HEIGHT		64

#ifdef VERTEX_SHADER
    // this is updated during transparent section
	#define SCOPE_TRANSPARENTS
#endif

#include "hlsl_constant_globals.fx"
#include "effects\cheap_particles_common.fx"

//#define QUAD_INDEX_MOD4
#include "shared\procedural_geometry.fx"


#ifdef pc

void default_vs(out float4 out_position : POSITION)		{ out_position= 0.0f; }
float4 default_ps() : COLOR0							{ return 0.0f; }

#else // XENON

#ifdef VERTEX_SHADER


// ------------- use global_render constants for atmosphere constants

#define FOG_ENABLED
#include "shared\atmosphere_core.fx"

#ifdef VERTEX_SHADER
	s_fog_light_constants					k_vs_fog_constants : register(c236);		// v_atmosphere_constant_4;
	s_atmosphere_precomputed_LUT_constants	k_vs_LUT_constants : register(c240);		// v_lighting_constant_0;
#endif // VERTEX_SHADER


void default_vs(
	in int index				: INDEX,
	out float4	out_position	: POSITION,
	out float4	out_texcoord	: TEXCOORD0,
	out float4  out_color		: TEXCOORD1,
	out float3	out_color_add	: TEXCOORD2 )
{
	out_color= float4( 0, 0, 0, 0 );

    // Determine the vertex index for this particle based on its particle index
	float particle_index= floor(index * (1.0f / VERTICES_PER_PARTICLE) + (0.5f / VERTICES_PER_PARTICLE));
	float vertex_index=	  index - particle_index * VERTICES_PER_PARTICLE;

	float2 particle_coord;
	
	const float2 inverse_texture_dimensions= (1.0f / PARTICLE_TEXTURE_WIDTH, 1.0f / PARTICLE_TEXTURE_HEIGHT);

	particle_coord.y= floor(particle_index * inverse_texture_dimensions.y);
	particle_coord.x= particle_index - particle_coord.y *  PARTICLE_TEXTURE_WIDTH;

	particle_coord= (particle_coord + 0.5) * inverse_texture_dimensions;

	// fetch particle data
	float4 position_and_age=		fetch_position_and_age(particle_index);

	if (abs(position_and_age.w) > 1.0)
	{
		// Only transform particle if it's active, otherwise transform to origin:
		out_position=	float4( NaN.xyzw );
		out_texcoord=	float4( NaN.xyzw );
		out_color=		float4( NaN.xyzw );
		out_color_add=	float3( NaN.xyz  );
	}
	else
	{
		// process active particles

		float4 velocity_and_delta_age=	fetch_velocity_and_delta_age(particle_index);
		float3 particle_position_world=  position_and_age.xyz;		
		float3 particle_to_camera_world= normalize(particle_position_world - Camera_Position);
		
		// move towards camera by a little bit			###ctchou $TODO this percentage should be controlled
		particle_position_world -=	particle_to_camera_world * 0.01f;

		float4	particle_parameters=			fetch_particle_parameters(particle_index);
		float	particle_type=					particle_parameters.x;
		float	illumination=					exp2(particle_parameters.y * (22/256.0) - 11);					// light range approximately between [2^-11, 2^11], gives us about 6.16% brightness steps
		float2	local_dx=						particle_parameters.zw / 63.5f;
				
		float4	render=							get_type_data(particle_type, TYPE_DATA_RENDER);
		float	texture_index=					render.x;
		float	max_size=						render.y;			// possibly can encode actual size in exponential space... no need for scalar max
		float	motion_blur_stretch_factor=		render.z;
		float	texture_y_scale=				render.w;	
		
		local_dx	*=							max_size;
		
		float	speed=							length(velocity_and_delta_age.xyz);
		float	stretch_scale=					max(motion_blur_stretch_factor * speed, 1.0f) / speed;
			
		// Basis contains velocity vector, and attempts to face screen (fix me)		// ###ctchou $TODO try to set camera_facing component to zero before normalizing.. ?
		float2x3 basis;
		basis[0]=			Camera_Right;
		basis[1]=			Camera_Up;

		if (texture_y_scale > 0)
		{
			basis[0]=			velocity_and_delta_age.xyz * stretch_scale;
			basis[1]=			normalize(cross(basis[0], particle_to_camera_world));	
		}
				
		float2 local_pos= generate_rotated_quad_point_2d(vertex_index, float2(0.0f, 0.0f), local_dx); 

		float3 position_world=	particle_position_world + mul(local_pos, basis);
		out_position=	float4(position_world, 1.0f);
		out_position=	mul(out_position, transpose(view_projection));

		float4 scatter_parameters=			get_atmosphere_fog_optimized_LUT(fog_table, k_vs_LUT_constants, k_vs_fog_constants, Camera_Position, position_world.xyz, k_vs_boolean_enable_atm_fog, true);

		float4	color0=						get_type_data(particle_type, TYPE_DATA_COLOR0);
		float4	fade=						get_type_data(particle_type, TYPE_DATA_FADE);
		
		float blend=						saturate(fade.a - abs(fade.a * position_and_age.w));
		out_color.rgb=						color0.rgb * blend * illumination;
		out_color.a=						saturate(color0.a * blend);
		
		out_color.rgb=						out_color.rgb * scatter_parameters.a;
		out_color_add.rgb=					scatter_parameters.rgb;
		
		out_texcoord.xy=					generate_quad_point_2d(vertex_index);
		out_texcoord.y=						(out_texcoord.y - 0.5f) * texture_y_scale + 0.5f;
		out_texcoord.z=						texture_index;
		out_texcoord.w=						0.0f;		// position_and_age.w;	
	}
}
#endif // VERTEX_SHADER


#ifdef PIXEL_SHADER

//sampler particle_texture : register(s0);

[maxtempreg(3)]
float4 default_ps(
	in float4 texcoord  : TEXCOORD0,
	in float4 color     : TEXCOORD1,
	in float3 color_add : TEXCOORD2) : COLOR0
{
	asm
	{
		tfetch3D	texcoord.xyzw,
					texcoord.xyz,
					render_texture,
					MagFilter= linear,
					MinFilter= linear,
					MipFilter= linear,
					VolMagFilter=	point,
					VolMinFilter=	point,
					AnisoFilter= disabled,	// max2to1,				// ###ctchou $TODO test anisotropic filtering cost -- could be good for the quality of very motion-blurred particles
					LODBias= -0.5
	};

	texcoord.rgba *=	color.rgba;
	
	return float4((texcoord.rgb  + color_add.rgb * texcoord.a) * g_exposure.x, texcoord.a / 32.0f);

}
#endif // PIXEL_SHADER

#endif // XENON