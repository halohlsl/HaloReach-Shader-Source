////#line 2 "source\rasterizer\hlsl\decorators.hlsl"

#include "effects\wind.fx"

#define SCOPE_MESH_DEFAULT
#include "hlsl_constant_globals.fx"

#include "shared\render_target.fx"
#include "shared\albedo_pass.fx"

#include "shared\atmosphere.fx"
#include "shared\quaternions.fx"

// light data goes where node data would normally be
VERTEX_CONSTANT(int, v_simple_light_count, k_register_node_per_vertex_count);
VERTEX_CONSTANT(float4, v_simple_lights[4 * k_maximum_simple_light_count], k_register_node_start); 

#ifdef VERTEX_SHADER
#define SIMPLE_LIGHT_DATA v_simple_lights
#define SIMPLE_LIGHT_COUNT v_simple_light_count
#undef dynamic_lights_use_array_notation			// decorators dont use array notation, they use loop-friendly notation
#include "lights\simple_lights.fx"
#endif // VERTEX_SHADER

#include "shared\atmosphere.fx"
#include "decorators\decorators.h"

#define pi 3.14159265358979323846

// decorator shader is defined as 'world' vertex type, even though it really doesn't have a vertex type - it does its own custom vertex fetches
//@generate decorator

/*
	POSITION	0:		vertex position
	TEXCOORD	0:		vertex texcoord
	POSITION	1:		instance position
	NORMAL		1:		instance quaternion
	COLOR		1:		instance color
	POSITION	2:		vertex index
*/


// per frame
VERTEX_CONSTANT(float4, v_cloud_motion, c230);
// 244
#define sun_direction v_analytical_light_direction
// 245
#define sun_color v_analytical_light_intensity
// 246: wind
// 247: wind

VERTEX_CONSTANT(float4, vs_antialias_scalars, c250);						// 
VERTEX_CONSTANT(float4, vs_object_velocity, c251);							// velocity of the current object, world space per object (approx)	###ctchou $TODO we could compute this in the vertex shader as a function of the bones...
VERTEX_CONSTANT(float4, vs_camera_velocity, c252);

PIXEL_CONSTANT(float3, contrast, c13);


// per block/instance/decorator_set
VERTEX_CONSTANT(float4, instance_compression_offset, c240);
VERTEX_CONSTANT(float4, instance_compression_scale, c241);
// Instance data holds the index count of one instance, as well as an index offset
// for drawing index buffer subsets.
VERTEX_CONSTANT(float4, instance_data, c242);
VERTEX_CONSTANT(float4, translucency, c243);

// depends on type
VERTEX_CONSTANT(float4, wave_flow, c249);		// phase direction + frequency



#include "templated\analytical_mask.fx"

float compute_antialias_blur_scalar(in float3 fragment_to_camera_world)
{
	float weighted_speed=	vs_object_velocity.w;
	float distance=			length(fragment_to_camera_world.xyz);
	float screen_speed=		weighted_speed / distance;						// approximate
	float output_alpha=		saturate(vs_antialias_scalars.z + vs_antialias_scalars.w * saturate(vs_antialias_scalars.x / (vs_antialias_scalars.y + screen_speed)));		// this provides a much smoother falloff than a straight linear scale
	return output_alpha;	
}



#define vertex_compression_scale Position_Compression_Scale
#define vertex_compression_offset Position_Compression_Offset
#define texture_compression UV_Compression_Scale_Offset


sampler2D			diffuse_texture : register(s0);			// pixel shader


#ifdef pc


#define pc_ambient_light p_lighting_constant_0
#define selection_point p_lighting_constant_1
#define selection_curve p_lighting_constant_2
#define selection_color p_lighting_constant_3

VERTEX_CONSTANT(float4, instance_position_and_scale, c17);
VERTEX_CONSTANT(float4, instance_quaternion, c18);

struct interpolators
{
	float4	position			:	POSITION;
	float2	texcoord			:	TEXCOORD0;
	float3	world_position		:	TEXCOORD1;
};

interpolators default_vs(
	float4 vertex_position : POSITION0,
	float2 vertex_texcoord : TEXCOORD0)
{
	interpolators OUT;

	// decompress position
	vertex_position.xyz= vertex_position.xyz * vertex_compression_scale.xyz + vertex_compression_offset.xyz;

	OUT.world_position= quaternion_transform_point(instance_quaternion, vertex_position.xyz) * instance_position_and_scale.w + instance_position_and_scale.xyz;
	OUT.position= mul(float4(OUT.world_position.xyz, 1.0f), View_Projection);
	OUT.texcoord= vertex_texcoord.xy * texture_compression.xy + texture_compression.zw;
	return OUT;
}

accum_pixel default_ps(
	in float2 texcoord : TEXCOORD0,
	in float3 world_position : TEXCOORD1)
{
//#define pc_ambient_light p_lighting_constant_0
//#define selection_point p_lighting_constant_1
//#define selection_curve p_lighting_constant_2
//#define selection_color p_lighting_constant_3

	float4 diffuse_albedo= tex2D(diffuse_texture, texcoord);
	clip(diffuse_albedo.a - k_decorator_alpha_test_threshold);				// alpha test
	
	float4 color= diffuse_albedo * pc_ambient_light * g_exposure.rrrr;

	// blend in selection cursor	
	float dist= distance(world_position, selection_point.xyz);
	float alpha= step(dist, selection_point.w);
	alpha *= selection_color.w;
	color.rgb= lerp(color.rgb, selection_color.rgb, alpha);

	// dim materials by wet
	color.rgb*= k_ps_wetness_coefficients.x;
	return convert_to_render_target(color, true, false);
}
	


#else	// xenon

struct interpolators
{
	float4	position			:	POSITION;
	float2	texcoord			:	TEXCOORD0;
	float4	ambient_light		:	TEXCOORD1;
};


#ifdef VERTEX_SHADER

void default_vs(
	in int index						:	INDEX,
	out float4	out_position			:	POSITION,
	out float4	out_texcoord			:	TEXCOORD0,
	out float4	out_ambient_light		:	TEXCOORD1
	)
{
	interpolators OUT;
	
    // what instance are we? - compute index to fetch from the instance stream
	int instance_index = floor(( index + 0.5 ) / instance_data.y);

	// fetch instance data
	float4 instance_position;
	float4 instance_auxilary_info;
	asm
	{
	    vfetch instance_auxilary_info,	instance_index, color2;
	    vfetch instance_position,	instance_index, position1;
	};
	instance_position.xyz= instance_position.xyz * instance_compression_scale.xyz + instance_compression_offset.xyz;
	
	float3 camera_to_vertex= (instance_position.xyz - Camera_Position);
	float distance= sqrt(dot(camera_to_vertex, camera_to_vertex));
	out_ambient_light.a= 1;
	
	
    // if the decorator is not completely faded
    {
	    float4 instance_quaternion;
	    float4 instance_color;
	    asm
	    {
	        vfetch instance_quaternion, instance_index, normal1;
		    vfetch instance_color, instance_index.x, color1;
	    };
    	
	    {
		    float type_index= instance_auxilary_info.x;
		    float motion_scale= instance_auxilary_info.y/256;

		    // compute the index index to fetch from the index buffer stream
		    float vertex_index= index - instance_index* instance_data.y;
		    

            vertex_index=min(vertex_index,instance_data.y-2);
            out_ambient_light.a=1-saturate((vertex_index-instance_data.z)*instance_data.w);                
	        
    	    {
            	
		        vertex_index+= type_index * instance_data.x;
		        

            	
		        // fetch the actual vertex
		        float4 vertex_position;
		        float2 vertex_texcoord;
		        float3 vertex_normal;
		        asm
		        {
			        vfetch vertex_position,	vertex_index.x, position0;
			        vfetch vertex_texcoord.xy, vertex_index.x, texcoord0;
			        vfetch vertex_normal.xyz, vertex_index.x, normal0;
		        };
		        vertex_position.xyz= vertex_position.xyz * vertex_compression_scale.xyz + vertex_compression_offset.xyz;
		        vertex_texcoord= vertex_texcoord.xy * texture_compression.xy + texture_compression.zw;
        		
		        float height_scale= 1.0f;
		        float2 wind_vector= 0.0f;

        #ifdef DECORATOR_WIND
		        // apply wind
		        wind_vector= sample_wind(instance_position.xy);
		        motion_scale *= saturate(vertex_position.z);										// apply model motion scale (increases linearly up to the top)
		        wind_vector.xy *= motion_scale;														// modulate wind vector by motion scale
        		
		        // calculate height offset	(change in height because of bending from wind)
		        float wind_squared= dot(wind_vector.xy, wind_vector.xy);							// how far did we move?
		        float instance_scale= dot(instance_quaternion.xyzw, instance_quaternion.xyzw);		// scale value
		        float height_squared= (instance_scale * vertex_position.z) + 0.01;
		        height_scale= sqrt(height_squared / (height_squared + wind_squared));
        #endif // DECORATOR_WIND

        #ifdef DECORATOR_WAVY
		        float phase= vertex_position.z * wave_flow.w + wind_data2.w * wave_flow.z + dot(instance_position.xy, wave_flow.xy);
		        float wave= motion_scale * saturate(abs(vertex_position.z)) * sin(phase);
		        vertex_position.x += wave;
        #endif // DECORATOR_WAVY

		        // combine the instance position with the mesh position
		        float4 world_position= vertex_position;
		        vertex_position.z *= height_scale;
        		
		        float3 rotated_position= quaternion_transform_point(instance_quaternion, vertex_position.xyz);
		        world_position.xyz= rotated_position + instance_position.xyz;										// max scale of 2.0 is built into vertex compression	
		        world_position.xy += wind_vector.xy * height_scale;													// apply wind vector after transformation

		        out_position= mul(float4(world_position.xyz, 1.0f), View_Projection);
        		
        #ifdef DECORATOR_SHADED_LIGHT	
		        float3 world_normal= rotated_position;
        #else
		        float3 world_normal= quaternion_transform_point(instance_quaternion, vertex_normal.xyz);
        #endif		
		        world_normal= normalize(world_normal);					// get rid of scale

		        float3 fragment_to_camera_world= Camera_Position - world_position.xyz;
		        float3 view_dir= normalize(fragment_to_camera_world);

		        float3 diffuse_dynamic_light= 0.0f;
        #ifdef DECORATOR_DYNAMIC_LIGHTS		
		        // point normal towards camera (two-sided only!)
		        float3 two_sided_normal= world_normal * sign(dot(world_normal, fragment_to_camera_world));
        		
		        // accumulate dynamic lights
		        calc_simple_lights_analytical_diffuse_translucent(
			        world_position,
			        two_sided_normal,
			        translucency,
			        diffuse_dynamic_light);
        #endif // DECORATOR_DYNAMIC_LIGHTS

		        out_texcoord.xy= vertex_texcoord;
		        out_texcoord.zw= 0.0f;	
		        
		        out_ambient_light.rgb= (instance_color.rgb * exp2(instance_color.a * 63.75 - 31.75)) + diffuse_dynamic_light ;

				[ifAny]		        
		        if(instance_auxilary_info.w>1)
		        {
					float2 cloud_texture_coordinate=get_analytical_mask_projected_texture_coordinate(world_position);
					float cloud= get_analytical_mask_from_projected_texture_coordinate(cloud_texture_coordinate,1,v_cloud_motion);
					float dotproduct;
			#ifdef PER_PLACEMENT_LIGHTING
					dotproduct= 0.65f;  
			#else
        
					dotproduct=saturate(dot(sun_direction,world_normal));
			#endif					
					
					float3 sun_light=dotproduct*sun_color*cloud*instance_auxilary_info.w/255/pi;					
					
					out_ambient_light.rgb += sun_light*instance_color.rgb; // multiply with the ldr color. instance_color.rgb is the lighting multiply tint color
		        }
        #ifdef DECORATOR_SHADED_LIGHT
		        out_texcoord.z= dot(rotated_position, sun_direction);				// position relative to decorator center, projected onto sun direction
        //		out_texcoord.w= dot(rotated_position, rotated_position);			// distance of position from decorator center (normalization term) - dividing z by w will give us a per-pixel cosine term
		        out_texcoord.w= sqrt(dot(rotated_position, rotated_position));		// distance of position from decorator center (normalization term) - dividing z by w will give us a per-pixel cosine term
		        out_texcoord.z= out_texcoord.z / out_texcoord.w;					// normalized projection == cosine lobe
        #endif // DECORATOR_SHADED_LIGHT
		       
        		
		        out_texcoord.w= 0.0f;
        	}
        }
	}
	
	out_texcoord.w= compute_antialias_blur_scalar(camera_to_vertex) * (1.0f / 32.0f);
}

#endif // VERTEX_SHADER


// ***************************************
// WARNING   WARNING   WARNING
// ***************************************
//    be careful changing this code.  it is optimized to use very few GPRs + interpolators
//			current optimized shader:	3 GPRs

float4 default_ps(
	in float4	texcoord			:	TEXCOORD0,	// z coordinate is unclamped cosine lobe for the 'sun', w: antialias
	in float4	ambient_light		:	TEXCOORD1   // w: cut from decimation
	) : COLOR0					// w unused
{
	float4 light= ambient_light;
#ifdef DECORATOR_SHADED_LIGHT
	{
		[isolate]				// this reduces GPRs by one	
		light.rgb *= saturate(texcoord.z) * contrast.y + contrast.x;
	}
#endif	
	float4 color= tex2D(diffuse_texture, texcoord.xy) * light;
	clip(color.a - k_decorator_alpha_test_threshold);							// alpha clip - removed since we are using alpha-to-coverage now
	
	// dim materials by wet
	color.rgb*= k_ps_wetness_coefficients.x;

	color.xyz *=g_exposure.r;
	color.w=texcoord.w;

	//color.a *= (0.5f / k_decorator_alpha_test_threshold);						// convert alpha for alpha-to-coverage (0.5f based)
	
	return color;
}

#endif // XENON

