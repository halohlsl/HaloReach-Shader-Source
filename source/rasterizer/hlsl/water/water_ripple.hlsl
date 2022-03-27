/*
WATER_RIPPLE.HLSL
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
04/12/2006 13:36 davcook	
*/

//This comment causes the shader compiler to be invoked for certain vertex types and entry points
//@generate ripple
//@entry default
//@entry active_camo
//@entry albedo
//@entry dynamic_light
//@entry shadow_apply

#include "hlsl_constant_globals.fx"
#include "shared\blend.fx"

// Attempt to auto-synchronize constant and sampler registers between hlsl and cpp code.
#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#ifdef VERTEX_SHADER
	#define VERTEX_CONSTANT(type, name, register_index)   type name : register(c##register_index);
	#define PIXEL_CONSTANT(type, name, register_index)   type name;
#else
	#define VERTEX_CONSTANT(type, name, register_index)   type name;
	#define PIXEL_CONSTANT(type, name, register_index)   type name : register(c##register_index);
#endif
#define BOOL_CONSTANT(name, register_index)   bool name : register(b##register_index);
#define SAMPLER_CONSTANT(name, register_index)	sampler name : register(s##register_index);
#include "water\water_registers.fx"

#include "shared\render_target.fx"

// rename entry point of water passes 
#define ripple_add_vs			active_camo_vs	
#define ripple_add_ps			active_camo_ps	
#define ripple_update_vs		default_vs
#define ripple_update_ps		default_ps
#define ripple_apply_vs			albedo_vs
#define ripple_apply_ps			albedo_ps
#define ripple_slope_vs			default_dynamic_light_vs
#define ripple_slope_ps			dynamic_light_ps
#define underwater_vs			shadow_apply_vs
#define underwater_ps			shadow_apply_ps

#ifndef pc /* implementation of xenon version */

//	ignore the vertex_type, input vertex type defined locally
struct s_ripple_vertex_input
{
	int index		:	INDEX;
};

struct s_ripple
{
	// pos_flow : position0
	float2 position;
	float2 flow;

	// life_height : texcoord0
	float life;	
	float duration;
	float rise_period;	
	float height;

	// shock_spread : texcoord1
	float2 shock;	
	float size;	
	float spread;

	// pendulum : texcoord2
	float pendulum_phase;
	float pendulum_revolution;
	float pendulum_repeat;

	// pattern : texcoord3
	float pattern_start_index;
	float pattern_end_index;

	// foam : texcoord4
	float foam_out_radius;
	float foam_fade_distance;
	float foam_life;
	float foam_duration;	

	// flags : color0
	bool flag_drift;	
	bool flag_pendulum;
	bool flag_foam;
	bool flag_foam_game_unit;

	// funcs : color1
	int func_rise;
	int func_descend;
	int func_pattern;
	int func_foam;	
};

// The following defines the protocol for passing interpolated data between vertex/pixel shaders
struct s_ripple_interpolators
{
	float4 position			:POSITION0;
	float4 texcoord			:TEXCOORD0;
	float4 pendulum			:TEXCOORD1;	
	float4 foam				:TEXCOORD2;	
};

struct s_underwater_interpolators
{
	float4 position			:POSITION0;
	float4 position_ss		:TEXCOORD0;
};

// magic number concentration camp, finally will be executed.
static const float k_ripple_time_per_frame= 0.033f;
static const int ripple_vertex_stream_block_num= 8; // number of float4 blocks inside structure

// grabbed from function.fx
#define _transition_function_linear		0
#define _transition_function_early		1 // x^0.5
#define _transition_function_very_early	2 // x^0.25
#define _transition_function_late		3 // x^2.0
#define _transition_function_very_late	4 // x^4.0
#define _transition_function_cosine		5 // accelerates in and out
#define _transition_function_one		6
#define _transition_function_zero		7
#define _transition_function_max		8

#define _2pi 6.28318530718f

#ifdef VERTEX_SHADER

// grabbed from function.fx
float evaluate_transition_internal(int transition_type, float input)
{
	float output;							
	if (transition_type==_transition_function_linear)
	{
		output= input;
	}
	else if (transition_type==_transition_function_early)
	{
		output= sqrt(input);
	}
	else if (transition_type==_transition_function_very_early)
	{
		output= sqrt(sqrt(input));
	}
	else if (transition_type==_transition_function_late)
	{
		output= input * input;
	}
	else if (transition_type==_transition_function_very_late)
	{
		output= input * input * input * input;
	}
	else if (transition_type==_transition_function_cosine)
	{
		output= cos(_2pi*(input+1));
	}
	else if (transition_type==_transition_function_one)
	{
		output= 1;
	}
	else //if (transition_type==_transition_function_zero)
	{
		output= 0;
	}
	return output;
}

// fetch a ripple particle
s_ripple fetch_ripple(int index)
{
	float4 position_flow;
	float4 life_height;
	float4 shock_size;
	float4 pendulum;
	float4 pattern;
	float4 foam;
	float4 flags;
	float4 funcs;	
	asm {
		vfetch position_flow,	index,	position0
		vfetch life_height,		index,	texcoord0
		vfetch shock_size,		index,	texcoord1
		vfetch pendulum,		index,	texcoord2
		vfetch pattern,			index,	texcoord3
		vfetch foam,			index,	texcoord4
		vfetch flags,			index,	color0
		vfetch funcs,			index,	color1
	};

	s_ripple OUT;
	OUT.position= position_flow.xy;
	OUT.flow= position_flow.zw;

	OUT.life= life_height.x;
	OUT.duration= life_height.y;
	OUT.rise_period= life_height.z;
	OUT.height= life_height.w;

	OUT.shock= shock_size.xy;
	OUT.size= shock_size.z;
	OUT.spread= shock_size.w;

	OUT.pendulum_phase= pendulum.x;
	OUT.pendulum_revolution= pendulum.y;
	OUT.pendulum_repeat= pendulum.z;

	OUT.pattern_start_index= pattern.x;
	OUT.pattern_end_index= pattern.y;

	OUT.foam_out_radius= foam.x;
	OUT.foam_fade_distance= foam.y;
	OUT.foam_life= foam.z;
	OUT.foam_duration= foam.w;

	OUT.flag_drift= flags.x;
	OUT.flag_pendulum= flags.y;
	OUT.flag_foam= flags.z;	
	OUT.flag_foam_game_unit= flags.w;

	OUT.func_rise= funcs.x;
	OUT.func_descend= funcs.y;
	OUT.func_pattern= funcs.z;
	OUT.func_foam= funcs.w;

	return OUT;
}


void ripple_add_vs(s_ripple_vertex_input IN)
{	
	const float4 k_offset_const= { 0, 1, 0, 0 };
	int index= IN.index;

	s_ripple ripple= fetch_ripple(index);

	// pack data
	float4 position_flow= float4(ripple.position, ripple.flow);
	float4 life_height= float4(ripple.life, ripple.duration, ripple.rise_period, ripple.height);
	float4 shock_spread= float4(ripple.shock, ripple.size, ripple.spread);
	float4 pendulum= float4(ripple.pendulum_phase, ripple.pendulum_revolution, ripple.pendulum_repeat, 0.0f);
	float4 pattern= float4(ripple.pattern_start_index, ripple.pattern_end_index, 0.0f, 0.0f);
	float4 foam= float4(ripple.foam_out_radius, ripple.foam_fade_distance, ripple.foam_life, ripple.foam_duration);
	float4 flags= float4(ripple.flag_drift, ripple.flag_pendulum, ripple.flag_foam, ripple.flag_foam_game_unit);
	float4 funcs= float4(ripple.func_rise, ripple.func_descend, ripple.func_pattern, ripple.func_foam);

	int dst_index= index + k_vs_ripple_particle_index_start;
	if ( dst_index >= k_vs_maximum_ripple_particle_number )
	{
		dst_index -= k_vs_maximum_ripple_particle_number;
	}

	// export to stream	
	int out_index_0= dst_index * ripple_vertex_stream_block_num;
	int out_index_1= out_index_0 + 1;
	int out_index_2= out_index_0 + 2;
	int out_index_3= out_index_0 + 3;
	int out_index_4= out_index_0 + 4;
	int out_index_5= out_index_0 + 5;		
	int out_index_6= out_index_0 + 6;		
	int out_index_7= out_index_0 + 7;			

	// only update, when ripple is alive
	asm
	{
		alloc export= 1
		mad eA, out_index_0, k_offset_const, k_vs_ripple_memexport_addr
		mov eM0, position_flow

		alloc export= 1
		mad eA, out_index_1, k_offset_const, k_vs_ripple_memexport_addr
		mov eM0, life_height

		alloc export= 1
		mad eA, out_index_2, k_offset_const, k_vs_ripple_memexport_addr
		mov eM0, shock_spread

		alloc export= 1
		mad eA, out_index_3, k_offset_const, k_vs_ripple_memexport_addr
		mov eM0, pendulum

		alloc export= 1
		mad eA, out_index_4, k_offset_const, k_vs_ripple_memexport_addr
		mov eM0, pattern

		alloc export= 1
		mad eA, out_index_5, k_offset_const, k_vs_ripple_memexport_addr
		mov eM0, foam

		alloc export= 1
		mad eA, out_index_6, k_offset_const, k_vs_ripple_memexport_addr
		mov eM0, flags

		alloc export= 1
		mad eA, out_index_7, k_offset_const, k_vs_ripple_memexport_addr
		mov eM0, funcs
	};

	// This is a workaround for a bug in >=Profile builds.  Without it, we get occasional 
	// bogus memexports from nowhere during effect-heavy scenes.
	asm {
	alloc export=1
		mad eA.xyzw, hidden_from_compiler.y, hidden_from_compiler.yyyy, hidden_from_compiler.yyyy
	};
	asm {
	alloc export=1
		mad eA.xyzw, hidden_from_compiler.z, hidden_from_compiler.zzzz, hidden_from_compiler.zzzz
	};
}


void ripple_update_vs(s_ripple_vertex_input IN)
{
	const float4 k_offset_const= { 0, 1, 0, 0 };
	int index= IN.index;

	s_ripple ripple= fetch_ripple(index);

	if (ripple.life > -0.1f)
	{		
		ripple.size+= ripple.spread * k_vs_ripple_real_frametime_ratio;
		ripple.pendulum_phase+= ripple.pendulum_revolution * k_vs_ripple_real_frametime_ratio;

		if ( ripple.flag_drift )
		{
			ripple.position+= ripple.flow * k_vs_ripple_real_frametime_ratio;
		}

		ripple.life-= k_ripple_time_per_frame * k_vs_ripple_real_frametime_ratio;
		ripple.foam_life-= k_ripple_time_per_frame * k_vs_ripple_real_frametime_ratio;
	}

	// pack data
	float4 position_flow= float4(ripple.position, ripple.flow);
	float4 life_height= float4(ripple.life, ripple.duration, ripple.rise_period, ripple.height);
	float4 shock_spread= float4(ripple.shock, ripple.size, ripple.spread);
	float4 pendulum= float4(ripple.pendulum_phase, ripple.pendulum_revolution, ripple.pendulum_repeat, 0.0f);
	float4 foam= float4(ripple.foam_out_radius, ripple.foam_fade_distance, ripple.foam_life, ripple.foam_duration);

	// export to stream	
	int out_index_0= index * ripple_vertex_stream_block_num;
	int out_index_1= out_index_0 + 1;
	int out_index_2= out_index_0 + 2;
	int out_index_3= out_index_0 + 3;
	// skip 4
	int out_index_5= out_index_0 + 5;		
	// skip 6
	// skip 7

	// only update, when ripple is alive
	asm
	{
		alloc export= 1
		mad eA, out_index_0, k_offset_const, k_vs_ripple_memexport_addr
		mov eM0, position_flow

		alloc export= 1
		mad eA, out_index_1, k_offset_const, k_vs_ripple_memexport_addr
		mov eM0, life_height

		alloc export= 1
		mad eA, out_index_2, k_offset_const, k_vs_ripple_memexport_addr
		mov eM0, shock_spread

		alloc export= 1
		mad eA, out_index_3, k_offset_const, k_vs_ripple_memexport_addr
		mov eM0, pendulum

		alloc export= 1
		mad eA, out_index_5, k_offset_const, k_vs_ripple_memexport_addr
		mov eM0, foam
	};

	// This is a workaround for a bug in >=Profile builds.  Without it, we get occasional 
	// bogus memexports from nowhere during effect-heavy scenes.
	asm {
	alloc export=1
		mad eA.xyzw, hidden_from_compiler.y, hidden_from_compiler.yyyy, hidden_from_compiler.yyyy
	};
	asm {
	alloc export=1
		mad eA.xyzw, hidden_from_compiler.z, hidden_from_compiler.zzzz, hidden_from_compiler.zzzz
	};
}

#define k_ripple_corners_number 16
static const float2 k_ripple_corners[k_ripple_corners_number]= { 
		float2(-1, -1), float2(0, -1), float2(0, 0), float2(-1, 0),
		float2(0, -1), float2(1, -1), float2(1, 0), float2(0, 0),
		float2(0, 0), float2(1, 0), float2(1, 1), float2(0, 1),
		float2(-1, 0), float2(0, 0), float2(0, 1), float2(-1, 1)};


s_ripple_interpolators ripple_apply_vs(s_ripple_vertex_input IN)
{			
	// fetch ripple
	int ripple_index= (IN.index + 0.5) / k_ripple_corners_number;	
	s_ripple ripple= fetch_ripple(ripple_index);
	
	s_ripple_interpolators OUT;
	if (ripple.life > -0.1f)
	{		
		int corner_index= IN.index - ripple_index * k_ripple_corners_number;	

		float3 shock_dir;
		if ( length(ripple.shock) < 0.01f ) 
		{
			shock_dir= float3(1.0f, 0.0f, 0.0f);
		}
		else
		{
			shock_dir= normalize(float3(ripple.shock, 0.0f));
		}

		float2 corner= k_ripple_corners[corner_index];

		float2 position;
		//position.x= -corner.x * shock_dir.x - corner.y * shock_dir.y;
		//position.y= corner.x * shock_dir.y - corner.y * shock_dir.x;

		position.y= -corner.x * shock_dir.x - corner.y * shock_dir.y;
		position.x= corner.x * shock_dir.y - corner.y * shock_dir.x;

		position= position*ripple.size + ripple.position;		

		position= (position - k_vs_camera_position.xy) / k_ripple_buffer_radius;					
		float len= length(position);
		position*= rsqrt(len);		

		position+= k_view_dependent_buffer_center_shifting;		

		float life_percent= max(ripple.life/ripple.duration, 0.0f);
		float period_in_life= 1.0f - life_percent;
		float pattern_index= lerp(ripple.pattern_start_index, ripple.pattern_end_index, evaluate_transition_internal(ripple.func_pattern, period_in_life));
		pattern_index= (pattern_index+0.5f) / k_vs_ripple_pattern_count;


		float ripple_height;
		if ( period_in_life < ripple.rise_period )
		{
			float rise_percentage= max(ripple.rise_period, 0.0001f); // avoid to be divded by zero
			ripple_height= life_percent * lerp(0.0f, ripple.height, evaluate_transition_internal(ripple.func_rise, period_in_life / rise_percentage));
		}
		else
		{
			float descend_percentage= max(1.0f-ripple.rise_period, 0.0001f); // avoid to be divded by zero
			ripple_height= life_percent * lerp(ripple.height, 0.0f, evaluate_transition_internal(ripple.func_descend, (period_in_life - ripple.rise_period)/descend_percentage));			
		}

		// calculate foam 
		float foam_opacity= 0.0f;
		float foam_out_radius= 0.0f;
		float foam_fade_distance= 0.0f; 
		if (ripple.flag_foam && ripple.foam_life>0)		
		{
			float period_in_foam_life= 1.0f - ripple.foam_life/ripple.foam_duration;
			foam_opacity= lerp(1.0f, 0.0f, evaluate_transition_internal(ripple.func_foam, period_in_foam_life));						

			// convert distances from object space into texture space
			if (ripple.flag_foam_game_unit)
			{
				foam_out_radius= ripple.foam_out_radius / ripple.size;
				foam_fade_distance= ripple.foam_fade_distance / ripple.size;
			}
			else
			{
				foam_out_radius= ripple.foam_out_radius;
				foam_fade_distance= ripple.foam_fade_distance;
			}
		}				

		// calculate pendulum
		if ( ripple.flag_pendulum )
		{
			ripple.pendulum_phase= abs(ripple.pendulum_phase); // guarantee always positive
		}
		else
		{
			ripple.pendulum_phase= -1.0f;	
		}

		// output
		OUT.position= float4(position.xy, 0.0f, 1.0f);
		OUT.texcoord= float4(corner*0.5f + 0.5f, pattern_index, ripple_height);
		OUT.pendulum= float4(ripple.pendulum_phase, ripple.pendulum_repeat, 0.0f, 0.0f); 
		OUT.foam= float4(foam_opacity, foam_out_radius, foam_fade_distance, 0.0f);

	}
	else 
	{
		OUT.position= 0.0f;	// invalidate position, kill primitive
		OUT.texcoord= 0.0f;
		OUT.pendulum= 0.0f;
		OUT.foam= 0.0f;
	}
	return OUT;
}

static const float2 k_screen_corners[4]= { 
		float2(-1, -1), float2(1, -1), float2(1, 1), float2(-1, 1) };

s_ripple_interpolators ripple_slope_vs(s_ripple_vertex_input IN)
{		
	float2 corner= k_screen_corners[IN.index];

	s_ripple_interpolators OUT;
	OUT.position= float4(corner, 0, 1);
	OUT.texcoord= float4(corner / 2 + 0.5, 0.0f, 0.0f);
	OUT.pendulum= 0.0f;
	OUT.foam= 0.0f;
	return OUT;
}

s_underwater_interpolators underwater_vs(s_ripple_vertex_input IN)
{	
	float2 corner= k_screen_corners[IN.index];

	s_underwater_interpolators OUT;
	OUT.position= float4(corner, 0, 1);
	OUT.position_ss= OUT.position;
	return OUT;
}


#endif //VERTEX_SHADER



#ifdef PIXEL_SHADER

//	should never been executed
float4 ripple_add_ps( void ) :COLOR0
{
	return float4(0,1,2,3);
}

//	should never been executed
float4 ripple_update_ps( void ) :COLOR0
{
	return float4(0,1,2,3);
}

float4 ripple_apply_ps( s_ripple_interpolators IN ) :COLOR0
{	
	//float height= tex3D(tex_ripple_pattern, IN.texcoord.xyz).r ;	
	float4 height_tex;
	float4 texcoord= IN.texcoord;
	asm
	{
		tfetch3D height_tex, texcoord.xyz, tex_ripple_pattern, MagFilter= linear, MinFilter= linear, MipFilter= linear, VolMagFilter= linear, VolMinFilter= linear
	};
	float height= (height_tex.r - 0.5f) * IN.texcoord.w;				
	
	// for pendulum
	[branch]
	if ( IN.pendulum.x > -0.01f)
	{
		float2 direction= IN.texcoord.xy*2.0f - 1.0f;
		float phase= IN.pendulum.x - length(direction) * IN.pendulum.y;
		height*= cos(phase);	
	}

	float4 OUT= 0.0f;	
	OUT.r= height.r;

	// for foam
	[branch]
	if ( IN.foam.x > 0.01f )
	{
		float2 direction= IN.texcoord.xy*2.0f - 1.0f;
		float distance= length(direction);

		distance= max(IN.foam.y - distance, 0.0f);
		float edge_fade= min( distance/max(IN.foam.z, 0.001f), 1.0f);
		OUT.g= edge_fade * IN.foam.x * height_tex.a;			
	}	

	return OUT;
}

float4 ripple_slope_ps( s_ripple_interpolators IN ) :COLOR0
{	
	float4 OUT= float4(0.5f, 0.5f, 0.5f, 0.0f);
	float4 texcoord= IN.texcoord;
	float4 tex_x1_y1;
	asm{ tfetch2D tex_x1_y1, texcoord, tex_ripple_buffer_height, MagFilter= point, MinFilter= point };

	//[branch]
	//if ( tex_x1_y1.a > 0.1f )
	{
		float4 tex_x2_y1, tex_x1_y2;
		asm{ tfetch2D tex_x2_y1, texcoord, tex_ripple_buffer_height, OffsetX= 1.0f, MagFilter= point, MinFilter= point };
		asm{ tfetch2D tex_x1_y2, texcoord, tex_ripple_buffer_height, OffsetY= 1.0f, MagFilter= point, MinFilter= point };

		float2 slope;
		slope.x= tex_x2_y1.r - tex_x1_y1.r;
		slope.y= tex_x1_y2.r - tex_x1_y1.r;
	   
		// Scale to [0 .. 1]		
		slope= saturate(slope * 0.5f + 0.5f);
		
		float4 org_OUT;
		org_OUT.r= saturate( (tex_x1_y1.r + 1.0f) * 0.5f );
		org_OUT.g= slope.x;
		org_OUT.b= slope.y;
		org_OUT.a= tex_x1_y1.g;

		// damping the brim	
		float2 distance_to_brim= saturate(100.0f *(0.497f - abs(IN.texcoord.xy-0.5f)));
		float lerp_weight= min(distance_to_brim.x, distance_to_brim.y);
		OUT= lerp(OUT, org_OUT, lerp_weight);
	}
	
	return OUT;
}

float compute_fog_factor( 
			float murkiness,
			float depth)
{
//	return 1.0f - saturate(1.0f / exp(murkiness * depth));	
	return 1.0f - saturate(exp2(-murkiness * depth));	
}


accum_pixel underwater_ps( s_underwater_interpolators INTERPOLATORS )
{	
	float3 output_color= 0;	

	// calcuate texcoord in screen space
	INTERPOLATORS.position_ss/= INTERPOLATORS.position_ss.w;
	float2 texcoord_ss= INTERPOLATORS.position_ss.xy;
	texcoord_ss= texcoord_ss / 2 + 0.5;
	texcoord_ss.y= 1 - texcoord_ss.y;
	texcoord_ss= k_ps_water_player_view_constant.xy + texcoord_ss*k_ps_water_player_view_constant.zw;

	// get pixel position in world space
	float distance= 0.0f;
	
	float pixel_depth= tex2D(tex_depth_buffer, texcoord_ss).r;		
	float4 pixel_position= float4(INTERPOLATORS.position_ss.xy, pixel_depth, 1.0f);		
	pixel_position= mul(pixel_position, k_ps_water_view_xform_inverse);
	pixel_position.xyz/= pixel_position.w;
	distance= length(k_ps_camera_position - pixel_position.xyz);	

	// get pixel color
	float3 pixel_color= tex2D(tex_ldr_buffer, texcoord_ss).rgb;
	pixel_color.rgb= (pixel_color.rgb < (1.0f/(16.0f*16.0f))) ? pixel_color.rgb : (exp2(pixel_color.rgb * (16 * 8) - 8));

	// calc under water fog
	float transparence= 0.5f * saturate(1.0f - compute_fog_factor(k_ps_underwater_murkiness, distance));						
	output_color= lerp(k_ps_underwater_fog_color*g_exposure.r, pixel_color, transparence);		
	
	return convert_to_render_target(float4(output_color, 1.0f), true, true);
}

#endif //PIXEL_SHADER



#else /* implementation of pc version */

struct s_ripple_interpolators
{
	float4 position	:POSITION0;
};

s_ripple_interpolators ripple_add_vs()
{
	s_ripple_interpolators OUT;
	OUT.position= 0.0f;
	return OUT;
}

s_ripple_interpolators ripple_update_vs()
{
	s_ripple_interpolators OUT;
	OUT.position= 0.0f;
	return OUT;
}

s_ripple_interpolators ripple_apply_vs()
{
	s_ripple_interpolators OUT;
	OUT.position= 0.0f;
	return OUT;
}

s_ripple_interpolators ripple_slope_vs()
{
	s_ripple_interpolators OUT;
	OUT.position= 0.0f;
	return OUT;
}

s_ripple_interpolators underwater_vs()
{
	s_ripple_interpolators OUT;
	OUT.position= 0.0f;
	return OUT;
}


float4 ripple_add_ps(s_ripple_interpolators INTERPOLATORS) :COLOR0
{
	return float4(0,1,2,3);
}

float4 ripple_update_ps(s_ripple_interpolators INTERPOLATORS) :COLOR0
{
	return float4(0,1,2,3);
}

float4 ripple_apply_ps(s_ripple_interpolators INTERPOLATORS) :COLOR0
{
	return float4(0,1,2,3);
}

float4 ripple_slope_ps(s_ripple_interpolators INTERPOLATORS) :COLOR0
{
	return float4(0,1,2,3);
}

float4 underwater_ps(s_ripple_interpolators INTERPOLATORS) :COLOR0
{
	return float4(0,1,2,3);
}

#endif //pc/xenon

// end of rename marco
#undef ripple_update_vs
#undef ripple_update_ps
#undef ripple_apply_vs	
#undef ripple_apply_ps	
#undef ripple_slope_vs	
#undef ripple_slope_ps	
#undef underwater_vs
#undef underwater_ps