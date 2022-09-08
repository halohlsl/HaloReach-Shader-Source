#ifndef _UTILITIES_FX_
#define _UTILITIES_FX_

#include "global.fx"

// fast is the speed optimized data type, when you don't need full float precision		-- stupid thing doesn't work with gamma correction though...

//#ifdef pc
//#define fast4 half4
//#define fast3 half3
//#define fast2 half2
//#define fast half
//#else // XENON
#define fast4 float4
#define fast3 float3
#define fast2 float2
#define fast float
//#endif

#define shadow_intenstiy_preserve_for_vmf 1.2f
// #define shadow_intenstiy_preserve_for_ambient 1.0f

#define raised_analytical_light_maximum 1.0f
#define raised_analytical_light_minimum 0.1f

// RGBE functions
/*
fast4 RGB_to_RGBE(in fast3 rgb)
{
	fast4 rgbe;
	fast maximum= max(max(rgb.r, rgb.g), rgb.b);
#ifdef pc
	maximum= max(maximum, 0.000000001f);			// ###ctchou $TODO this in a hack to get nVidia cards to work (for some reason they often return negative zero) - remove this in Xenon builds through a #define
#endif
	fast exponent;
	fast mantissa= frexp(maximum, exponent);		// note this is an expensive function
	rgbe.rgb= rgb.rgb * (mantissa / maximum);
	rgbe.a= (exponent + 128) / 255.0f;
	return rgbe;
}

fast3 RGBE_to_RGB(in fast4 rgbe)
{
	return rgbe.rgb * ldexp(1.0, rgbe.a * 255.0f - 128);
}
*/

float4 convert_to_bloom_buffer(in float3 rgb)
{
	return float4(rgb, 1.0f); //RGB_to_RGBE(rgb);
}

float3 convert_from_bloom_buffer(in float4 rgba)
{
	return rgba.rgb; //RGBE_to_RGB(rgba);
}

float color_to_intensity(in float3 rgb)
{
	return dot(rgb, float3( 0.299f, 0.587f, 0.114f ));
}

// Convert from XYZ to RGB
float3 convert_xyz_to_rgb(float3 xyz)
{
	float3x3 mat_XYZ_to_rgb = {float3(3.240479f, -1.537150f, -0.498535f), float3(-0.969256f, 1.875991f, 0.041556f), float3(0.055648f, -0.204043f, 1.057311f)};
	float3 rgb= mul(xyz, mat_XYZ_to_rgb);
	return rgb;
}

// Convert from rgb to xyy
float3 convert_rgb_to_xyz(float3 rgb)
{
	float3x3 mat_rgb_to_XYZ = {float3(0.412424f, 0.357579f, 0.180464f), float3(0.212656f, 0.715158f, 0.0721856f), float3(0.0193324f,  0.119193f , 0.950444f)};
	float3 xyz= mul(rgb, mat_rgb_to_XYZ);
	return xyz;
}

// Convert from XYZ to RGB
float3 convert_xyy_to_rgb(float3 xyy)
{
	float3 xyz;
	xyz.x= xyy.x * (xyy.y / xyy.z);
	xyz.y= xyy.y;
	xyz.z= (1.0f - xyy.x - xyy.z)* (xyy.y/xyy.z);
	float3 rgb= convert_xyz_to_rgb(xyz);
	return rgb;
}

// Convert from rgb to xyy
float3 convert_rgb_to_xyy(float3 rgb)
{
	float3 xyz= convert_rgb_to_xyz(rgb);
	float3 xyy;
	//to xyy
	xyy.x= xyz.x/(xyz.x + xyz.y + xyz.z);
	xyy.y= xyz.y;
	xyy.z= xyz.y/(xyz.x + xyz.y + xyz.z);
	return xyy;
}


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
float apply_black_point(float black_point, float alpha)
{
	float mid_point= (black_point+1.0f)/2.0f;
	return mid_point*saturate((alpha-black_point)/(mid_point-black_point))
		+ saturate(alpha-mid_point);	// faster than a branch
}


float3 Screen(float3 cb, float3 cs)
{
	return cb+cs-(cb*cs);
}

float Screen(float cb, float cs)
{
	return cb+cs-(cb*cs);
}

float3 HardLight(float3 cb, float3 cs)
{
	float3 result;
	result.x= cs.x<=0.5?cb.x*cs.x*2:Screen(cb.x, 2*cs.x-1);
	result.y= cs.y<=0.5?cb.y*cs.y*2:Screen(cb.y, 2*cs.y-1);
	result.z= cs.z<=0.5?cb.z*cs.z*2:Screen(cb.z, 2*cs.z-1);
	return result;
}

float soft_light_helper(float x)
{
	if(x<=0.25)
	{
		return ((16*x-12)*x+4)*x;
	}
	else
	{
		return sqrt(x);
	}
}

float soft_light(float b, float s)
{
	if (s<=0.5)
	{
		return b- (1 - 2 * s) * b * (1 - b);
	}
	else
	{
		return b + (2 * s - 1) * (soft_light_helper(b) - b);
	}
}

float3 Overlay(float3 cb, float3 cs)
{
	return HardLight(cs, cb);
}

float3 detail_apply(float3 cb, float3 cs)
{
	return cb*cs*2;
}

// safe normalize function that returns 0 for zero length vectors (360 normalize does this by default)
float3 safe_normalize(in float3 v)
{
#ifdef XENON
	return normalize(v);
#else
	float l = dot(v,v);
	if (l > 0)
	{
		return v * rsqrt(l);
	} else
	{
		return 0;
	}
#endif
}
// safe sqrt function that returns 0 for inputs that are <= 0
float safe_sqrt(in float x)
{
#ifdef XENON
	return sqrt(x);
#else
	return (x <= 0) ? 0 : sqrt(x);
#endif
}
float2 safe_sqrt(in float2 x)
{
#ifdef XENON
	return sqrt(x);
#else
	return (x <= 0) ? 0 : sqrt(x);
#endif
}

float3 safe_sqrt(in float3 x)
{
#ifdef XENON
	return sqrt(x);
#else
	return (x <= 0) ? 0 : sqrt(x);
#endif
}

float4 safe_sqrt(in float4 x)
{
#ifdef XENON
	return sqrt(x);
#else
	return (x <= 0) ? 0 : sqrt(x);
#endif
}

// safe pow function that always returns 1 when y is 0
#if DX_VERSION == 11
float safe_pow(float x, float y)
{
	if (y == 0)
	{
		return 1;
	} else
	{
		return pow(x, y);
	}
}
#else
float safe_pow(float x, float y)
{
	return pow(x, y);
}
#endif

#if DX_VERSION == 11
// convert normalized 3d texture z coordinate to texture array coordinate
float4 Convert3DTextureCoordToTextureArray(in texture_sampler_2d_array t, in float3 uvw)
{
	uint width, height, elements;
	t.t.GetDimensions(width, height, elements);

	float half_recip_elements = 0.5f / elements;

	return float4(
		uvw.xy,
		saturate(uvw.zz + float2(-half_recip_elements, half_recip_elements)) * elements);
}

float4 sampleArrayWith3DCoords(in texture_sampler_2d_array t, in float3 uvw)
{
	float4 array_texcoord = Convert3DTextureCoordToTextureArray(t, uvw);
	float frac_z = frac(array_texcoord.z);
	array_texcoord.zw = floor(array_texcoord.zw);
	return lerp(
		sample3D(t, array_texcoord.xyz),
		sample3D(t, array_texcoord.xyw),
		frac_z);
}

// gets x/y gradients in same format as Xenon getGradients instruction (although does not take sampler into account)
float4 GetGradients(in float2 value)
{
	float2 x_gradient = ddx(value);
	float2 y_gradient = ddy(value);
	return float4(x_gradient.x, y_gradient.x, x_gradient.y, y_gradient.y);
}
#endif

#endif //ifndef _UTILITIES_FX_