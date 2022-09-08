//#line 2 "source\rasterizer\hlsl\lit_particle_overdraw_apply.hlsl"

#define POSTPROCESS_USE_CUSTOM_VERTEX_SHADER

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
#include "shared\texture.fx"
#include "shared\quaternions.fx"
#include "shared\matrix.fx"
#include "effects\lit_particle_overdraw_apply_registers.fx"
//@generate screen

struct interpolators
{
	float4 position				:SV_Position;
	float2 texcoord				:TEXCOORD0;
	float4 light_direction		:TEXCOORD1;		// light direction and alpha
};

#ifdef pc	// --------- pc -------------------------------------------------------------------------------------
interpolators default_vs(
	vertex_type IN)
{
	interpolators OUT;
	OUT.texcoord=		IN.texcoord;
	OUT.position.xy=	IN.position;
	OUT.position.zw=	1.0f;
	OUT.light_direction.xyzw= 1.0f;
	return OUT;
}
#elif defined(durango)
interpolators default_vs(
	in uint instance_id : SV_InstanceID,
	in uint vertex_id : SV_VertexID)
{
	screen_output OUT;

	uint2 tile_coord = tile_buffer[instance_id];
	float2 quad_point = generate_quad_point_2d(vertex_id);

	OUT.position = float4(((tile_coord * tile_scale_offset.xy) + tile_scale_offset.zw) + (quad_point * quad_scale.xy), 0, 1);
	OUT.texcoord = (tile_coord + quad_point) * quad_scale.zw;

	float2 screen_coords=	(OUT.position / float2(2.0f, -2.0f)) + float2(1.0f, 1.0f);

	// convert world_space_light to relative direction at that pixel...
	float3 camera_space_pixel_vector=	float3(screen_coords * tangent_transform.xy + tangent_transform.zw, 1.0f);
	float3x3 rotation=			normalize_rotation_matrix_from_vectors(float3(1.0f, 0.0f, 0.0f), float3(0.0f, 1.0f, 0.0f), camera_space_pixel_vector);
	OUT.light_direction.xyz=	normalize(mul(transpose(rotation), camera_space_light.xyz));

	OUT.light_direction.a=		saturate(-OUT.light_direction.z);
					//saturate(dot(normalize(-camera_space_pixel_vector.xyz), normalize(camera_space_light.xyz)));

	OUT.light_direction.a	*=	OUT.light_direction.a;
	OUT.light_direction.a	*=	OUT.light_direction.a;
	OUT.light_direction.a	*=	OUT.light_direction.a;

	return OUT;
}
#else		// --------- xenon ----------------------------------------------------------------------------------
interpolators default_vs(
	in int index						:	SV_VertexID)
{
	interpolators OUT;

	float	quad_index=		floor(index / 4);						//		[0,	x*y-1]
	float	quad_vertex=	index -	quad_index * 4;					//		[0, 2]

	float2	quad_coords;
	quad_coords.y=	floor(quad_index * quad_tiling.y);				//		[0, y-1]
	quad_coords.x=	quad_index - quad_coords.y * quad_tiling.x;		//		[0, x-1]

	float2	subquad_coords;
	subquad_coords.y=	floor(quad_vertex / 2);						//		[0, 1]
	subquad_coords.x=	quad_vertex - subquad_coords.y * 2;			//		[0, 1]

	if (subquad_coords.y > 0)
	{
		subquad_coords.x= 1-subquad_coords.x;
	}

	quad_coords += subquad_coords;

	// build interpolator output

	OUT.position.xy=		quad_coords * position_transform.xy + position_transform.zw;
	OUT.position.zw=		1.0f;

	OUT.texcoord=			quad_coords * texture_transform.xy + texture_transform.zw;

	float2 screen_coords=	quad_coords * quad_tiling.yw;

	// convert world_space_light to relative direction at that pixel...
	float3 camera_space_pixel_vector=	float3(screen_coords * tangent_transform.xy + tangent_transform.zw, 1.0f);
	float3x3 rotation=			normalize_rotation_matrix_from_vectors(float3(1.0f, 0.0f, 0.0f), float3(0.0f, 1.0f, 0.0f), camera_space_pixel_vector);
	OUT.light_direction.xyz=	normalize(mul(transpose(rotation), camera_space_light.xyz));

	OUT.light_direction.a=		saturate(-OUT.light_direction.z);
					//saturate(dot(normalize(-camera_space_pixel_vector.xyz), normalize(camera_space_light.xyz)));

	OUT.light_direction.a	*=	OUT.light_direction.a;
	OUT.light_direction.a	*=	OUT.light_direction.a;
	OUT.light_direction.a	*=	OUT.light_direction.a;

	return OUT;
}
#endif		// --------- xenon ----------------------------------------------------------------------------------

float4 default_ps(interpolators IN) : SV_Target
{
	float4 color;
#if defined(pc) && (DX_VERSION == 9)
 	color= sample2D(source_sampler, IN.texcoord);
#else // xenon

	float2 texcoord0= IN.texcoord;
	float4 tex0, tex1;
#ifdef xenon
	asm
	{
		tfetch2D tex0, texcoord0, source_sampler, MagFilter = linear, MinFilter = linear, MipFilter = point, AnisoFilter = disabled
		tfetch2D tex1, texcoord0, source_lowres_sampler, MagFilter = linear, MinFilter = linear, MipFilter = point, AnisoFilter = disabled
	};
#elif DX_VERSION == 11
	tex0 = sample2D(source_sampler, texcoord0);
	tex1 = sample2D(source_lowres_sampler, texcoord0);
#endif

//	float backlit=	saturate(-IN.light_direction.z);
//	backlit *= backlit;
//	backlit *= backlit;
//	backlit *= backlit * tex0.a;

	tex0.xy= tex0.rg * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f);
	tex1.xy= tex1.rg * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f);

#ifdef xenon
	[isolate]
#endif
	{

	float3 vec;
	vec.xy= tex0.xy + light_params.x * tex1.xy;
	vec.z= light_params.y * (1.0f - tex0.a) * (1.0f - tex1.a) * (1.0 - saturate(dot(tex0.xy, tex0.xy)));
	vec.xyz= normalize(vec.xyz);

	float lit= dot(vec.xyz, IN.light_direction.xyz);			// + 1.5f * darken * darken - 1.3f;

	// analytic lightig
//	color.rgb= p_lighting_constant_8.rgb * saturate(lit * light_spread.x + light_spread.y) * tex0.b +		// * saturate(lit * 0.50f + 0.50f)
//			   p_lighting_constant_9.rgb * saturate(lit * light_spread.z + light_spread.w);

	// palette based lighting
	float4 palette=	sample2D(palette_sampler, float2(lit * 0.5f + 0.5f, tex0.b));
	color.rgb= palette.rgb * (p_lighting_constant_9.rgb + palette.a * p_lighting_constant_8.rgb);

	color.rgb= color.rgb * (1.0f - tex0.a);
	color.a= tex0.a;

	}

#endif
 	return color*scale;
}
