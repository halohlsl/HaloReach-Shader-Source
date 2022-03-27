#ifndef pc


#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#include "effects\cheap_particle_system_registers.h"


#define TYPE_TEXTURE_WIDTH 256
#define TYPE_TEXTURE_HEIGHT 8


#ifdef VERTEX_SHADER

#define TYPE_DATA_PHYSICS		(0.0)
#define TYPE_DATA_COLLISION		(1.0)
#define	TYPE_DATA_COLOR0		(2.0)
#define	TYPE_DATA_FADE			(3.0)
#define	TYPE_DATA_RENDER		(4.0)

float4 get_type_data(float particle_type, float type_data_index)
{
	float4	result;
	float2	texcoord=	float2(particle_type, type_data_index);
	asm
	{
		tfetch2D	result,
					texcoord,
					type_texture,
					UnnormalizedTextureCoords= true,
					MagFilter= point,
					MinFilter= point,
					MipFilter= point,
					AnisoFilter= disabled,
					UseComputedLOD= false,
					UseRegisterGradients= false
//					OffsetX=	0.5,
//					OffsetY=	0.5
	};
	return result;
}


float4 generate_random(float particle_index, sampler2D random_sampler, float4 texture_transform)
{
	// Compute a random value by looking up into the noise texture based on particle coordinate:
	float2	random_texcoord=	particle_index * texture_transform.xy + texture_transform.zw;
	
	float4 random;
	asm
	{
		tfetch2D random,
				 random_texcoord,
				 random_sampler,
				 UnnormalizedTextureCoords= false,
				 MagFilter= point,
				 MinFilter= point,
				 MipFilter= point,
				 AnisoFilter= disabled,
				 UseComputedLOD= false,
				 UseRegisterGradients=false
	};
	return random;
}


float4 fetch_position_and_age(float particle_index)
{
	float4 position_and_age;
	asm
	{
		vfetch position_and_age, particle_index, position0
	};
	return position_and_age.xyzw;
}

float4 fetch_velocity_and_delta_age(float particle_index)
{
	float4 velocity_and_delta_age;
	asm
	{
		vfetch velocity_and_delta_age, particle_index, texcoord0
	};
	return velocity_and_delta_age.xyzw;
}

float4 fetch_particle_parameters(float particle_index)
{
	float4 particle_parameters;
	asm
	{
		vfetch particle_parameters, particle_index, texcoord1
	};
	return particle_parameters.xyzw;
}


void memexport_position_and_age(float relative_particle_index, float4 position_and_age)
{
	const float4 k_offset_const= { 0, 1, 0, 0 };
	asm
	{
		alloc export= 1
		mad eA, relative_particle_index, k_offset_const, position_age_address_offset
		mov eM0, position_and_age
	};
}

void memexport_velocity_and_delta_age(float relative_particle_index, float4 velocity_and_delta_age)
{
	const float4 k_offset_const= { 0, 1, 0, 0 };
	asm
	{
		alloc export= 1
		mad eA, relative_particle_index, k_offset_const, velocity_and_delta_age_address_offset
		mov eM0, velocity_and_delta_age
	};
}

void memexport_particle_parameters(float relative_particle_index, float4 particle_parameters)
{
	const float4 k_offset_const= { 0, 1, 0, 0 };
	asm
	{
		alloc export= 1
		mad eA, relative_particle_index, k_offset_const, parameters_address_offset
		mov eM0, particle_parameters
	};
}

#endif // VERTEX_SHADER




#endif // pc