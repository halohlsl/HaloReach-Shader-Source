#ifndef __POWER_ROUGHNESS_CONVERSION_FX__
#define __POWER_ROUGHNESS_CONVERSION_FX__


// THIS FILE IS INCLUDED IN HLSL AND C, DON'T USE ANYTHING FUNKY HERE


#define K_ROUGHNESS_TO_POWER_SCALE		(0.27291f)

// original value from line fit:
//#define K_ROUGHNESS_TO_POWER_EXPONENT	(-2.19732f)

// Xi's modified hack value:
#define K_ROUGHNESS_TO_POWER_EXPONENT	(-1.3973f)

#define K_POWER_TO_ROUGHNESS_SCALE		(0.553773f)
#define K_POWER_TO_ROUGHNESS_EXPONENT	(-0.4551f)


#ifdef SHADER_30
	// HLSL
	#define DECL
	#define PRECLAMP_ROUGHNESS(value)
	#define PRECLAMP_POWER(value)
	#define POSTCLAMP_POWER(value)
	#define POSTCLAMP_ROUGHNESS(value)
#else
	// C code
	#define DECL inline
	#define PRECLAMP_ROUGHNESS(value)	{ value= MAX(value, 0.01f); }
	#define PRECLAMP_POWER(value)		{ value= PIN(value, 0.01f, 2000.f); }
	#define POSTCLAMP_POWER(value)		{ value= MAX(value, 0.00f);	}
	#define POSTCLAMP_ROUGHNESS(value)	{ value= PIN(value, 0.f, 1.f); }
#endif



DECL float roughness_to_power(float roughness)
{
	PRECLAMP_ROUGHNESS(roughness);
	float power= K_ROUGHNESS_TO_POWER_SCALE * pow(roughness, K_ROUGHNESS_TO_POWER_EXPONENT);
	POSTCLAMP_POWER(power);
	
	return power;
}


DECL float power_to_roughness(float power)
{
	PRECLAMP_POWER(power);
	float roughness= K_POWER_TO_ROUGHNESS_SCALE * pow(power, K_POWER_TO_ROUGHNESS_EXPONENT);
	POSTCLAMP_ROUGHNESS(roughness);
	
	return roughness;
}


#undef DECL
#undef PRECLAMP_ROUGHNESS
#undef PRECLAMP_POWER
#undef POSTCLAMP_POWER
#undef POSTCLAMP_ROUGHNESS


/*
inline real roughness_to_power(
	real roughness)
{
	// very low roughness not well defined
	roughness= MAX(roughness, 0.01f);
	
	real power= 0.27291f * pow(roughness, -2.1973f);
	
	// power must be >=0
	power= MAX(power, 0.f);

	return power;
}

inline real power_to_roughness(
	real power)
{
	// really low power undefined, clamp at some large value because it doesn't change afterwards
	power= PIN(power, 0.01f, 2000.f);

	real roughness= pow(power/0.27291f, 1.f/-2.1973f);	
	
	// roughness must be between 0 and 1
	roughness= PIN(roughness, 0.f, 1.f);

	return roughness;
}
*/


#endif // __POWER_ROUGHNESS_CONVERSION_FX__