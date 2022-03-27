#define POSTPROCESS_USE_CUSTOM_VERTEX_SHADER

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
#include "shared\texture_xform.fx"


#undef PIXEL_CONSTANT
#undef VERTEX_CONSTANT
#include "hlsl_registers.fx"
#define	SHADER_CONSTANT(	hlsl_type,	hlsl_name,	code_name,	register_start,	register_count,	scope, register_bank, stage, command_buffer_option)		hlsl_type hlsl_name stage##_REGISTER(register_bank##register_start);
	#include "hlsl_constant_declaration_defaults.fx"
	#include "postprocess\final_composite_registers.fx"
	#include "hlsl_constant_declaration_defaults_end.fx"
#undef SHADER_CONSTANT
#undef VERTEX_REGISTER
#undef PIXEL_REGISTER



// define default functions, if they haven't been already

#ifndef COMBINE
#define COMBINE default_combine_optimized
#endif // !COMBINE

#ifndef COMBINE_AA
#define COMBINE_AA default_combine_antialiased
#endif // !COMBINE

#ifndef CALC_BLOOM
#define CALC_BLOOM default_calc_bloom
#endif // !CALC_BLOOM

#ifndef CALC_BLEND
#define CALC_BLEND default_calc_blend
#endif // !CALC_BLEND

#ifndef CONVERT_OUTPUT
#define CONVERT_OUTPUT convert_output_gamma2
#endif // !CONVERT_OUTPUT

#ifndef CONVERT_OUTPUT_AA
#define CONVERT_OUTPUT_AA convert_output_antialiased
#endif // !CONVERT_OUTPUT)AA


struct final_composite_screen_output
{
	float4 position:		 POSITION;
	float2 texcoord:		 TEXCOORD0;
	float4 xformed_texcoord: TEXCOORD1;	// xy - pixel-space texcoord, zw - noise-space texcoord
};

final_composite_screen_output default_vs(vertex_type IN)
{
	final_composite_screen_output OUT;
	OUT.texcoord=		IN.texcoord;
	OUT.position.xy=	IN.position;
	OUT.position.zw=	1.0f;

	// Convert the [0,1] input texture coordinates into pixel space. Note that this transform must include the appropriate
	// scale and bias for screenshot tile offsets
	float2 pixel_space_texcoord= IN.texcoord * pixel_space_xform.xy + pixel_space_xform.zw;

	// Transform pixel space texture coordinates to tile the noise texture such as to maintain 1:1 fetch ratio
	float2 noise_space_texcoord= pixel_space_texcoord * noise_space_xform.xy + noise_space_xform.zw;	

	OUT.xformed_texcoord= float4( pixel_space_texcoord, noise_space_texcoord );

	return OUT;
}

struct s_default_ps_output
{
	float4 color : COLOR0;
};

struct s_antialiased_ps_output
{
    float4 antialias_result	: COLOR0;
    float4 curframe_result	: COLOR1;
};


float4 default_combine_optimized(in float2 texcoord)						// final game code: single sample LDR surface, use hardcoded hardware curve
{
	return tex2D(surface_sampler, texcoord) * float4(DARK_COLOR_MULTIPLIER, DARK_COLOR_MULTIPLIER, DARK_COLOR_MULTIPLIER, 32.0f);
}


float4 default_combine_antialiased(in float2 texcoord, in bool centered)
{
#ifdef pc
	return tex2D(surface_sampler, texcoord) * float4(DARK_COLOR_MULTIPLIER, DARK_COLOR_MULTIPLIER, DARK_COLOR_MULTIPLIER, 32.0f);
#else // xenon

	#define tfetch(color, texcoord, sampler, offsetx, offsety)		asm	{	tfetch2D color, texcoord, sampler, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, OffsetX= offsetx, OffsetY= offsety	}

    float4 color;
    if (centered)
    {
		tfetch(color, texcoord, surface_sampler, 0.0f,  0.0f);
    }
    else
    {       
       float4 temp;
       tfetch(temp, texcoord, surface_sampler,  0.0f,  0.0f);
		 color=		temp;
       tfetch(temp,    texcoord, surface_sampler, -1.0f,  0.0f);
         color.rgb    +=    temp.rgb;
         color.a    =    max(color.a, temp.a);
       tfetch(temp,    texcoord, surface_sampler, -1.0f, -1.0f);
         color.rgb    +=    temp.rgb;
         color.a    =    max(color.a, temp.a);
       tfetch(temp,    texcoord, surface_sampler,  0.0f, -1.0f);
         color.rgb    +=    temp.rgb;
         color.a    =    max(color.a, temp.a);
       color.rgb    *=    0.25f;
    }
	return color * float4(DARK_COLOR_MULTIPLIER, DARK_COLOR_MULTIPLIER, DARK_COLOR_MULTIPLIER, 32.0f);
#endif // xenon
}

// Note that we're expecting the texture coordinate already be transformed to pixel space when this method is called:
float4 default_calc_bloom(in float2 pixel_space_texcoord)
{
	float4 bloom=	tex2D_offset(bloom_sampler, pixel_space_texcoord, 0, 0);
//	return float4(bloom.rgb * bloom.rgb, bloom.a);					// 8-bit gamma2 (###ctchou $TODO)
	return bloom;
}


float3 default_calc_blend(in float2 texcoord, in float4 combined, in float4 bloom)
{
#ifdef pc
	return combined + bloom;
#else // XENON
//	return combined * bloom.a + bloom.rgb;
	return combined + bloom.rgb;
#endif // XENON
}

 
void apply_color_adjustments(
	inout float3 color)
{
#ifndef pc
	// apply contrast (4 instructions)
//	float luminance= dot(color, float3(0.333f, 0.333f, 0.333f));
//	color *= pow(luminance,		gamma.w);								// (x^gamma)/x			==	pow(luminance, p_postprocess_contrast.x) / luminance == pow(luminance, p_postprocess_contrast.w)
	color.rgb=	pow(color.rgb,	gamma.x);								// (x^gamma)

	// apply hue and saturation (3 instructions)
	color= saturate(mul(float4(color, 1.0f), color_matrix));
#endif // !pc
}


void convert_to_gamma2_and_apply_color_adjustments(
	inout float3 color)
{
#ifndef pc
	color.rgb=	pow(color.rgb,	gamma.z);								// sqrt(x^gamma)

	// apply color matrix (3 instructions)
	color= saturate(mul(float4(color, 1.0f), color_matrix));
#endif // !pc
}


float3 apply_tone_curve(
	in float3 color)
{
	// apply tone curve (4 instructions)
//	float3 clamped  = min(blend, tone_curve_constants.xxx);		// default= 1.4938015821857215695824940046795		// r1
	float3 clamped  = saturate(color);
	return	((clamped.rgb * tone_curve_constants.w + tone_curve_constants.z) * clamped.rgb + tone_curve_constants.y) * clamped.rgb;		// default linear = 1.0041494251232542828239889869599, quadratic= 0, cubic= - 0.15;
}


s_default_ps_output convert_output_7e3(in float4 result, in float2 texcoord)					// 10-bit 7e3
{
	s_default_ps_output output;
//	output.color.rgb=		result.rgb;
	output.color.rgb=		result.rgb*result.rgb;							// convert to linear from gamma2
	output.color.a=			(1.0f / 32.0f - result.a);						// 32.0f for the -5 exponent bias
	return output;
}

s_default_ps_output convert_output_gamma2(in float4 result, in float2 texcoord)					// 8-bit gamma2
{
	s_default_ps_output output;
//	output.color.rgb=		sqrt(result.rgb);
	output.color.rgb=		result.rgb;				// already in gamma2 space
	output.color.a=			result.a;
	return output;
}

s_antialiased_ps_output convert_output_antialiased(in float4 result, in float2 texcoord)
{
	s_antialiased_ps_output output;
	
    [branch]
    if (result.a < 1.0f)														// magically optimizing branch
    {
       float4 prev=					tex2D(prev_sampler, texcoord);
       
       float min_velocity=			max(result.a, prev.a);
       float expected_velocity=		sqrt(min_velocity);							// if we write estimated velocity into the alpha channel, we can use them here
       float2 weights=				lerp(float2(0.5f, 0.5f), float2(0.0f, 1.0f), expected_velocity);
       float3 linear_blend=			weights.x * (prev.rgb * prev.rgb) + weights.y * (result.rgb * result.rgb);

       // 8-bit gamma2
       output.curframe_result=		float4(result.rgb, result.a);
       output.antialias_result=		float4(sqrt(linear_blend.rgb),	1.0f);
	}
    else
    {
       // 8-bit gamma2
       output.curframe_result=		float4(result.rgb, result.a);
       output.antialias_result=		float4(result.rgb, 1.0f);
    }
    
    return output;
}


float4 apply_noise( in float2 noise_space_texcoord, in float4 input_color )
{
	float4 output_color= input_color;

	float4 noise;

	#ifdef pc
		noise= float4( 0.8, 0.8, 0.0, 1.0 );
	#else	// XENON		
		asm    
		{    
			tfetch2D noise, 
					 noise_space_texcoord, 
					 noise_sampler, 
					 MagFilter= point, 
					 MinFilter= point, 
					 MipFilter= point, 
					 AnisoFilter= disabled, 
					 OffsetX= 0.0f, 
					 OffsetY= 0.0f    
		};
	#endif	

	noise.xy=			noise.zz * noise_params.xy + noise_params.zw;
	output_color.rgb=	output_color.rgb * noise.xxx + noise.yyy;

	return output_color;
}


// non-antialiased
s_default_ps_output default_ps(	in float2 texcoord			: TEXCOORD0, 
								in float4 xformed_texcoord	: TEXCOORD1		// xy - pixel-space texcoord, zw - noise-space texcoord
							)
{
	// final composite
	float4 combined=	COMBINE(texcoord);											// sample and blend full resolution render targets
	float4 bloom=		CALC_BLOOM(xformed_texcoord.xy);							// sample postprocessed buffer(s) using pixel space texture coordinates
	float3 blend=		CALC_BLEND(texcoord, combined, bloom);						// blend them together

	convert_to_gamma2_and_apply_color_adjustments(blend);

	float4 result;
	result.rgb=			blend;				// apply_tone_curve(blend);
	result.a=			combined.a;

	s_default_ps_output output= CONVERT_OUTPUT(result, texcoord);
	
	output.color = apply_noise( xformed_texcoord.zw, output.color );

	return output;
}


// non-antialiased, save frame
final_composite_screen_output shadow_apply_vs(vertex_type IN)
{
	return default_vs(IN);
}
s_antialiased_ps_output shadow_apply_ps(in float2 texcoord:			TEXCOORD0, 
							   in float4 xformed_texcoord:  TEXCOORD1 // xy - pixel-space texcoord, zw - noise-space texcoord
							   )
{
	// final composite
	float4 combined=	COMBINE(texcoord);											// sample and blend full resolution render targets
	float4 bloom=		CALC_BLOOM(xformed_texcoord.xy);							// sample postprocessed buffer(s) using pixel space texture coordinates
	float3 blend=		CALC_BLEND(texcoord, combined, bloom);						// blend them together

	convert_to_gamma2_and_apply_color_adjustments(blend);

	float4 result;
	result.rgb=			blend;				// apply_tone_curve(blend);
	result.a=			combined.a;

	s_default_ps_output temp=	CONVERT_OUTPUT(result, texcoord);

	s_antialiased_ps_output output;
	output.antialias_result=	output.curframe_result=		temp.color;
		
	output.antialias_result = apply_noise( xformed_texcoord.zw, output.antialias_result );

	return output;	
}


// antialiased centered
final_composite_screen_output albedo_vs(vertex_type IN)
{
	return default_vs(IN);
}
s_antialiased_ps_output albedo_ps(in float2 texcoord:		   TEXCOORD0, 
								  in float4 xformed_texcoord:  TEXCOORD1 // xy - pixel-space texcoord, zw - noise-space texcoord
							     )
{
	// final composite
	float4 combined=	COMBINE_AA(texcoord, true);									// sample and blend full resolution render targets
	float4 bloom=		CALC_BLOOM(xformed_texcoord.xy);							// sample postprocessed buffer(s) using pixel space texture coordinates
	float3 blend=		CALC_BLEND(texcoord, combined, bloom);						// blend them together

	convert_to_gamma2_and_apply_color_adjustments(blend);

	float4 result;
	result.rgb=			blend;				// apply_tone_curve(blend);
	result.a=			combined.a;
	
	s_antialiased_ps_output output= CONVERT_OUTPUT_AA(result, texcoord);
	
	output.antialias_result = apply_noise( xformed_texcoord.zw, output.antialias_result );

	return output;
}


// antialiased non-centered
final_composite_screen_output static_sh_vs(vertex_type IN)
{
	return default_vs(IN);
}
s_antialiased_ps_output static_sh_ps(in float2 texcoord:		 TEXCOORD0, 
									 in float4 xformed_texcoord: TEXCOORD1 // xy - pixel-space texcoord, zw - noise-space texcoord
							        )
{
	// final composite
	float4 combined=	COMBINE_AA(texcoord, false);								// sample and blend full resolution render targets
	float4 bloom=		CALC_BLOOM(xformed_texcoord.xy);							// sample postprocessed buffer(s) using pixel space texture coordinates
	float3 blend=		CALC_BLEND(texcoord, combined, bloom);						// blend them together

	convert_to_gamma2_and_apply_color_adjustments(blend);

	float4 result;
	result.rgb=			blend;				// apply_tone_curve(blend);
	result.a=			combined.a;

    s_antialiased_ps_output output= CONVERT_OUTPUT_AA(result, texcoord);

	output.antialias_result = apply_noise( xformed_texcoord.zw, output.antialias_result );
		
	return output;
}
