#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

LOCAL_SAMPLER_2D(shadow_sampler, 0);
LOCAL_SAMPLER_2D(image_sampler, 1);

#if !defined(pc) || (DX_VERSION == 11)

float4 fetch7e3( texture_sampler_2d s, float2 vTexCoord )
{
	float4 vColor;

	//  This is done in assembly to emphasize POINT SAMPLING.
	//  If you do not point sample, you will be averaging floating data
	//  as an integer and errors will be introduced.  You do not have to do this
	//  if you set your sampler states correctly, but this is just a safety.
	//  You can choose to filter as integer but it will not be accurate.
#ifdef xenon
	asm
	{
		tfetch2D vColor.bgra, vTexCoord.xy, s, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled
	};

	// Now that we have the color, we just need to perform standard 7e3 conversion.

	// Shift left 3 bits. This allows us to have the exponent and mantissa on opposite
	// sides of the decimal point for extraction.
	// We comment this out, because this is done instead in the state as Format.ExpAdjust = 3
	// If we didn't do that in the sampler state, we would do it here.
	// vColor.rgb *= 8.0f;

	// Extract the exponent and mantissa that are now on opposite sides of the decimal point.
	float3 e = floor( vColor.rgb );
	float3 m = frac( vColor.rgb );

	// Perform the 7e3 conversion.  Note that this varies on the value of e for each channel:
	// if e != 0.0f then the correct conversion is (1+m)/8*pow(2,e).
	// else it is (1+m)/8*pow(2,e).
	// Note that 2^0 = 1 so we can reduce this more.
	// Removing the /8 and putting it inside the pow() does not save instructions
	vColor.rgb  = (e == 0.0f) ? 2*m/8 : (1+m)/8 * pow(2,e);

	return vColor;
#elif DX_VERSION == 11
	return s.t.Load(int3(vTexCoord.xy, 0));
#endif
}
#endif

float4 default_ps(screen_output IN, SCREEN_POSITION_INPUT(vpos)) : SV_Target
{
#if defined(pc) && (DX_VERSION == 9)
 	return 1.0f;
#else
	float4 result_shadow;
	float4 result_image;
#ifdef xenon
	asm {
		tfetch2D result_shadow, vpos, shadow_sampler, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled
	};
#elif DX_VERSION == 11
	result_shadow= shadow_sampler.t.Load(int3(vpos.xy, 0));
#endif
	result_image= fetch7e3(image_sampler, vpos);

	// we're going to mix the direct and ambient shadow amounts, 50/50 to get the darkening percentage for decorators
	float shadow_darkness=	dot(result_shadow.ra, float2(0.5f, 0.5f));

	return float4(result_image.rgb * shadow_darkness * g_exposure.www, result_image.a / 8.0f / 32.0f);
#endif
}
