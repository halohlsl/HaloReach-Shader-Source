#if !defined(pc) || (DX_VERSION == 11)


#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#include "effects\cheap_particle_system_registers.h"

#if DX_VERSION == 11
#include "shared\packed_vector.fx"
#endif

#define TYPE_TEXTURE_WIDTH 256
#define TYPE_TEXTURE_HEIGHT 8

#if DX_VERSION == 11
	#ifdef CHEAP_PARTICLE_CORE_VS
		#define particle_state_buffer vs_particle_state_buffer
		#define type_texture vs_type_texture
	#else
		#define particle_state_buffer cs_particle_state_buffer
		#define type_texture cs_type_texture
	#endif
#endif

#define TYPE_DATA_PHYSICS		(0.0)
#define TYPE_DATA_COLLISION		(1.0)
#define	TYPE_DATA_COLOR0		(2.0)
#define	TYPE_DATA_FADE			(3.0)
#define	TYPE_DATA_RENDER		(4.0)

float4 get_type_data(float particle_type, float type_data_index)
{
	float4	result;
	float2	texcoord=	float2(particle_type, type_data_index);
#ifdef xenon
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
#elif DX_VERSION == 11
	result = type_texture.t.Load(int3(texcoord, 0));
#endif
	return result;
}


float4 generate_random(float particle_index, texture_sampler_2d random_sampler, float4 texture_transform)
{
	// Compute a random value by looking up into the noise texture based on particle coordinate:
	float2	random_texcoord=	particle_index * texture_transform.xy + texture_transform.zw;

	float4 random;
#ifdef xenon
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
#elif DX_VERSION == 11
	random = sample2Dlod(random_sampler, random_texcoord, 0);
#endif
	return random;
}


float4 fetch_position_and_age(float particle_index)
{
	float4 position_and_age;
#ifdef xenon
	asm
	{
		vfetch position_and_age, particle_index, position0
	};
#elif DX_VERSION == 11
	position_and_age = particle_state_buffer[particle_index].position_age;
#endif
	return position_and_age.xyzw;
}

float4 fetch_velocity_and_delta_age(float particle_index)
{
	float4 velocity_and_delta_age;
#ifdef xenon
	asm
	{
		vfetch velocity_and_delta_age, particle_index, texcoord0
	};
#elif DX_VERSION == 11
	velocity_and_delta_age = UnpackHalf4(particle_state_buffer[particle_index].velocity_delta_age);
#endif
	return velocity_and_delta_age.xyzw;
}

float4 fetch_particle_parameters(float particle_index)
{
	float4 particle_parameters;
#ifdef xenon
	asm
	{
		vfetch particle_parameters, particle_index, texcoord1
	};
#elif DX_VERSION == 11
	particle_parameters = UnpackSByte4(particle_state_buffer[particle_index].parameters);
#endif
	return particle_parameters.xyzw;
}


void memexport_position_and_age(float relative_particle_index, float4 position_and_age)
{
	const float4 k_offset_const= { 0, 1, 0, 0 };
#ifdef xenon
	asm
	{
		alloc export= 1
		mad eA, relative_particle_index, k_offset_const, position_age_address_offset
		mov eM0, position_and_age
	};
#elif DX_VERSION == 11
	cs_particle_state_buffer[relative_particle_index].position_age = position_and_age;
#endif
}

void memexport_velocity_and_delta_age(float relative_particle_index, float4 velocity_and_delta_age)
{
	const float4 k_offset_const= { 0, 1, 0, 0 };
#ifdef xenon
	asm
	{
		alloc export= 1
		mad eA, relative_particle_index, k_offset_const, velocity_and_delta_age_address_offset
		mov eM0, velocity_and_delta_age
	};
#elif DX_VERSION == 11
	cs_particle_state_buffer[relative_particle_index].velocity_delta_age = PackHalf4(velocity_and_delta_age);
#endif
}

void memexport_particle_parameters(float relative_particle_index, float4 particle_parameters)
{
	const float4 k_offset_const= { 0, 1, 0, 0 };
#ifdef xenon
	asm
	{
		alloc export= 1
		mad eA, relative_particle_index, k_offset_const, parameters_address_offset
		mov eM0, particle_parameters
	};
#elif DX_VERSION == 11
	cs_particle_state_buffer[relative_particle_index].parameters = PackSByte4(particle_parameters);
#endif
}


#endif // pc