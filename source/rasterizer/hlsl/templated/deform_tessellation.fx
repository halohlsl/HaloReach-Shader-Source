#include "hlsl_vertex_types.fx"
#include "templated\deform.fx"

/****************************************************************************************************
*****************************************************************************************************

DEFORM.FX
Copyright (c) Microsoft Corporation 2008 all rights reserved.
2/22/2008 3:59:02 PM (xwan)
	should be separate file

*****************************************************************************************************
****************************************************************************************************/

#ifndef pc

/****************************************************************************************************

	Basic functions

****************************************************************************************************/


float4 blend_float4(
			float4 a,
			float4 b,
			float4 c,
			float3 weights)
{
	[isolate]
	{
		return a*weights.z + b*weights.y + c*weights.x;
	}
}

float3 blend_float3(
			float3 a,
			float3 b,
			float3 c,
			float3 weights)
{
	[isolate]
	{
		return a*weights.z + b*weights.y + c*weights.x;
	}
}


float2 blend_float2(
			float2 a,
			float2 b,
			float2 c,
			float3 weights)
{
	[isolate]
	{
		return a*weights.z + b*weights.y + c*weights.x;
	}
}

float blend_float(
			float a,
			float b,
			float c,
			float3 weights)
{
	return a*weights.z + b*weights.y + c*weights.x;
}

bool is_degenerate_triangle(
	in int3 indices)
{
	const int index_unequal=
		(indices.x - indices.y) * 
		(indices.z - indices.y) * 
		(indices.x - indices.z);

	return (index_unequal == 0);
}

#define PN_w(i, j)  (dot(P[j]-P[i], N[i]))
float3 PN_position(
	 const float3 P[4],	// 0 is unused
	 const float3 N[4],	// 0 is unused
	 const float3 weights)
{
	const float delta= k_vs_tessellation_parameter.w;

	const float3 b300= P[1];
	const float3 b030= P[2];
	const float3 b003= P[3];
	const float3 b210= (2*P[1] + P[2] - delta*PN_w(1, 2)*N[1]) / 3.0f;
	const float3 b120= (2*P[2] + P[1] - delta*PN_w(2, 1)*N[2]) / 3.0f;
	const float3 b021= (2*P[2] + P[3] - delta*PN_w(2, 3)*N[2]) / 3.0f;
	const float3 b012= (2*P[3] + P[2] - delta*PN_w(3, 2)*N[3]) / 3.0f;
	const float3 b102= (2*P[3] + P[1] - delta*PN_w(3, 1)*N[3]) / 3.0f;
	const float3 b201= (2*P[1] + P[3] - delta*PN_w(1, 3)*N[1]) / 3.0f;

	const float3 E= (b210 + b120 + b021 + b012 + b102 + b201) / 6.0f;
	const float3 V= (P[1] + P[2] + P[3]) / 3.0f;
	const float3 b111= E + (E - V)/2.0f;

	//const float3 b210= P[1];
	//const float3 b120= P[2];
	//const float3 b021= P[2];
	//const float3 b012= P[3];
	//const float3 b102= P[3];
	//const float3 b201= P[1];
	//const float3 b111= (P[1] + P[2] + P[3])/3.0f;	

	const float w= weights.z;
	const float u= weights.y;
	const float v= weights.x;	

	const float3 out_P=
		b300*w*w*w + b030*u*u*u + b003*v*v*v +
		b210*3*w*w*u + b120*3*w*u*u + b201*3*w*w*v +
		b021*3*u*u*v + b102*3*w*v*v + b012*3*u*v*v +
		+ b111*6*w*u*v;

	return out_P;
}
#undef PN_w

#define PN_v(i, j) (2.0f * dot(P[j]-P[i], N[i]+N[j]) / dot(P[j]-P[i], P[j]-P[i]) )
float3 PN_normal(
	 const float3 P[4],
	 const float3 N[4],
	 const float3 weights)
{
	const float delta= k_vs_tessellation_parameter.w;

	const float3 n200= N[1];
	const float3 n020= N[2];
	const float3 n002= N[3];

	const float3 h110= N[1] + N[2] - delta*PN_v(1, 2)*(P[2] - P[1]);
	const float3 h011= N[2] + N[3] - delta*PN_v(2, 3)*(P[3] - P[2]);
	const float3 h101= N[3] + N[1] - delta*PN_v(3, 1)*(P[1] - P[3]);

	const float3 n110= normalize(h110);
	const float3 n011= normalize(h011);
	const float3 n101= normalize(h101);

	//const float3 n110= (N[1] + N[2])/2;
	//const float3 n011= (N[2] + N[3])/2;
	//const float3 n101= (N[3] + N[1])/2;

	const float w= weights.z;
	const float u= weights.y;
	const float v= weights.x;

	const float3 out_N=
		n200*w*w + n020*u*u + n002*v*v +
		n110*w*u + n011*u*v + n101*w*v;

	return out_N;
}
#undef PN_v


static const int CACHE_GEOMETRY_PARAM_NUM= 4;
static const int MAX_CACHE_LIGHT_PARAM_NUM= 2;
static const int TESSELLATION_SHADER_CACHE_STREAM_NUM= CACHE_GEOMETRY_PARAM_NUM + MAX_CACHE_LIGHT_PARAM_NUM; 

static const float4 k_offset_const= { 0, 1, 0, 0 };
#define k_tess_cache_memexport_addr k_vs_tessellation_parameter
#define hidden_from_compiler k_vs_hidden_from_compiler

/****************************************************************************************************

	For lighting

****************************************************************************************************/

void light_fetch_prt_ambient(
	in int v_index,
	out float prt_c0)
{	
	float prt_fetch_index= v_index * 0.25f;								// divide vertex index by 4
	float prt_fetch_fraction= frac(prt_fetch_index);					// grab fractional part of index (should be 0, 0.25, 0.5, or 0.75) 

	float4 prt_values, prt_component;
	float4 prt_component_match= float4(0.75f, 0.5f, 0.25f, 0.0f);				// bytes are 4-byte swapped (each dword is stored in reverse order)
	asm
	{
		vfetch	prt_values, prt_fetch_index, blendweight1						// grab four PRT samples
		seq		prt_component, prt_fetch_fraction.xxxx, prt_component_match		// set the component that matches to one		
	};
	prt_c0= dot(prt_component, prt_values);
}

/****************************************************************************************************

	For geometry

****************************************************************************************************/

void fetch_cache_vertex_geometry(
	in int vindex,
	out s_shader_cache_vertex vertex)
{
	float4 pos, tex, nml, tan, bnl, lpt;
	asm {
		vfetch pos, vindex, position0
		vfetch tex, vindex, texcoord0
		vfetch nml, vindex, normal0
		vfetch tan, vindex, tangent0
		vfetch bnl, vindex, binormal0
		vfetch lpt, vindex, texcoord1
	};

	vertex.position= pos; ///256 + col/256;	
	vertex.normal= nml;
	vertex.texcoord= tex;
	vertex.tangent= tan;
	vertex.binormal= bnl;
	vertex.light_param= lpt;	
}

void memory_export_geometry_to_stream(
	 in int v_index,
	 in vertex_type vertex,
	 in float4 light_param)
{

	float4 pos= float4(vertex.position - Camera_Position, 0);
	const float4 tex= float4(vertex.texcoord, 0, 0);
	const float4 nml= float4(vertex.normal, 0);
	const float4 tan= float4(vertex.tangent, 0);
	float4 bnl;//= float4(vertex.binormal, 0);
			// derive binormal from normal and tangent plus a flag in position.w
			float binormal_scale= (vertex.position.w*2.f)-1.f;
			bnl.xyz= cross(vertex.normal, vertex.tangent);
			bnl.xyz= mul(bnl, binormal_scale);
			bnl= float4(normalize(bnl.xyz), 0);

	// export to stream	
	int out_index_0= v_index * TESSELLATION_SHADER_CACHE_STREAM_NUM;
	int out_index_4= out_index_0 + 4;
	asm
	{
		alloc export= 2
		mad eA, out_index_0, k_offset_const, k_tess_cache_memexport_addr
		mov eM0, pos						
		mov eM1, tex
		mov eM2, nml
		mov eM3, tan

		alloc export= 2		
		mad eA, out_index_4, k_offset_const, k_tess_cache_memexport_addr
		mov eM0, bnl						
		mov eM1, light_param
	};
}

void memory_export_flush()
{
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


void fetch_vertex_world(
	in int vindex,
	out s_world_vertex vertex)
{
	float4 pos, tex;
	float4 nml, tan;
	asm {
		vfetch pos, vindex, position0
		vfetch tex, vindex, texcoord0

		vfetch nml, vindex, normal0
		vfetch tan, vindex, tangent0
	};

	vertex.position= pos;
	vertex.texcoord= tex;

	vertex.normal= nml;
	vertex.tangent= tan;
}

void fetch_vertex_rigid(
	in int vindex,
	out s_rigid_vertex vertex)
{
	float4 pos, tex;
	float4 nml, tan;
	asm {
		vfetch pos, vindex, position0
		vfetch tex, vindex, texcoord0

		vfetch nml, vindex, normal0
		vfetch tan, vindex, tangent0
	};	

	vertex.position= pos;
	vertex.texcoord= tex;

	vertex.normal= nml;
	vertex.tangent= tan;
}



void fetch_vertex_skinned(
	in int vindex,
	out s_skinned_vertex vertex)
{
	float4 pos, tex, nidx, nwgt;
	float4 nml, tan;
	asm {
		vfetch pos, vindex, position0
		vfetch tex, vindex, texcoord0
		vfetch nidx, vindex, blendindices
		vfetch nwgt, vindex, blendweight

		vfetch nml, vindex, normal0
		vfetch tan, vindex, tangent0
	};


	vertex.position= pos;
	vertex.texcoord= tex;
	vertex.node_indices= nidx;
	vertex.node_weights= nwgt;

	vertex.normal= nml;
	vertex.tangent= tan;
}


void deform_world_tessellated(
	in int v_index,
	out s_world_tessellated_vertex vertex,
	out float4 local_to_world_transform[3])
{		
	fetch_vertex_world(v_index, vertex);
	deform_world(vertex, local_to_world_transform);
}


void deform_rigid_tessellated(
	in int v_index,
	out s_rigid_tessellated_vertex vertex,
	out float4 local_to_world_transform[3])
{
	fetch_vertex_rigid(v_index, vertex);
	deform_rigid(vertex, local_to_world_transform);	
}

void deform_skinned_tessellated(
    in int v_index,
	out s_skinned_tessellated_vertex vertex,
	out float4 local_to_world_transform[3])
{
	fetch_vertex_skinned(v_index, vertex);
	deform_skinned(vertex, local_to_world_transform);
}

#define ONLY_TESS_LEVEL_2


// extremly cheaper version of tessellation of level 2
#ifdef ONLY_TESS_LEVEL_2

	#define PN_w(i, j)  (dot(P[j]-P[i], N[i]))

	float3 calc_b(
		const float3 P[4],	// 0 is unused
		const float3 N[4],	// 0 is unused
		uniform int i, 
		uniform int j)
	{
		float3 result;
		const float delta= k_vs_tessellation_parameter.w;
		result= (2*P[i] + P[j] - delta*PN_w(i, j)*N[i]) / 3.0f;	
		return result;
	}

	float3 PN_position_asm(
		 const in float3 P[4],		 
		 const in float3 N[4])
	{	
		float3 out_P;
		[isolate]
		{
			const float3 b300= P[1];
			out_P= b300*0.125;
		}

		[isolate]
		{
			const float3 b030= P[2];
			out_P+= b030*0.125;
		}

		[isolate]
		{
			const float3 b210= calc_b(P, N, 1, 2); //(2*P[1] + P[2] - delta*PN_w(1, 2)*N[1]) / 3.0f;
			out_P+= b210*0.375;
		}

		[isolate]
		{
			const float3 b120= calc_b(P, N, 2, 1); //(2*P[2] + P[1] - delta*PN_w(2, 1)*N[2]) / 3.0f;			
			out_P+= b120*0.375;
		}

		return out_P;
	}

	int calc_GUID_index_from_weights(
	   in float3 uvw)
	{
		uvw= uvw*2;
		return round(uvw.y*3 + uvw.x);
	}

	#define u_idx		2			// value C
	#define v_idx		1			// value B
	#define w_idx		0			// value A
	#define NONE		-1


	static const int2 GUID_index_to_blend_map[7]=
	{
		//	index1		index2
		int2(w_idx,		w_idx),		// (u= 0, v= 0, w= 2, 
		int2(u_idx,		w_idx),		// (u= 1, v= 0, w= 1, 
		int2(u_idx,		u_idx),		// (u= 2, v= 0, w= 0, 
		int2(v_idx,		w_idx),		// (u= 0, v= 1, w= 1, 
		int2(u_idx,		v_idx),		// (u= 1, v= 1, w= 0, 
		int2(NONE,		NONE),		// (u= 2, v= 1, w= NONE, 
		int2(v_idx,		v_idx),		// (u= 0, v= 2, w= 0, 
	};


	bool blend_cache_geometry_by_indices(
		in s_vertex_type_trilist_index indices,
		out s_shader_cache_vertex out_vertex,
		out float4 position)
	{	
		int v_indices[3];
		v_indices[0]= indices.index.x;
		v_indices[1]= indices.index.y;
		v_indices[2]= indices.index.z;

		int GUID_id= calc_GUID_index_from_weights(indices.uvw);
		int2 blend_map= GUID_index_to_blend_map[GUID_id];		


		s_shader_cache_vertex vertex1, vertex2;	
		fetch_cache_vertex_geometry(v_indices[blend_map.x], vertex1);
		fetch_cache_vertex_geometry(v_indices[blend_map.y], vertex2);		


		// using NP patch tessellation
		float3 P[4];
		P[0]= 0;
		P[1]= vertex1.position;
		P[2]= vertex2.position;
		P[3]= 0;

		float3 N[4];
		N[0]= 0;
		N[1]= vertex1.normal;
		N[2]= vertex2.normal;
		N[3]= 0;

		out_vertex.position= float4(PN_position_asm(P, N), 1.f);

		out_vertex.normal= (vertex1.normal + vertex2.normal) * 0.5f;
		out_vertex.texcoord= (vertex1.texcoord + vertex2.texcoord) * 0.5f;
		out_vertex.tangent= (vertex1.tangent + vertex2.tangent) * 0.5f;
		out_vertex.binormal= (vertex1.binormal + vertex2.binormal) * 0.5f;
		out_vertex.light_param= (vertex1.light_param + vertex2.light_param) * 0.5f;

		// add camera position back
		out_vertex.position.xyz+= Camera_Position;

		// transform postion from world to view
		position= mul(out_vertex.position, View_Projection);	

		if (is_degenerate_triangle(indices.index))
		{					
			position= k_vs_hidden_from_compiler;		
		}

		return true;
	}

#else //ONLY_TESS_LEVEL_2

	#define PN_w(i, j)  (dot(P[j]-P[i], N[i]))

	float3 calc_b(
		const float3 P[4],	// 0 is unused
		const float3 N[4],	// 0 is unused
		uniform int i, 
		uniform int j)
	{
		float3 result;
		const float delta= k_vs_tessellation_parameter.w;
		result= (2*P[i] + P[j] - delta*PN_w(i, j)*N[i]) / 3.0f;	
		return result;
	}

	float3 PN_position_asm(
		 const float3 P[4],	// 0 is unused
		 const float3 N[4],	// 0 is unused
		 const float3 weights)
	{	
		const float w= weights.z;
		const float u= weights.y;
		const float v= weights.x;	

		float3 out_P;

		[isolate]
		{
			const float3 b300= P[1];
			out_P= b300*w*w*w;
		}

		[isolate]
		{
			const float3 b030= P[2];
			out_P+= b030*u*u*u;
		}

		[isolate]
		{
			const float3 b003= P[3];
			out_P+=  b003*v*v*v;
		}

		const float3 V= (P[1] + P[2] + P[3]) / 3.0f;
		float3 b111= -0.5f*V;

		float3 E= 0;

		[isolate]
		{
			const float3 b210= calc_b(P, N, 1, 2); //(2*P[1] + P[2] - delta*PN_w(1, 2)*N[1]) / 3.0f;
			E= b210;
			out_P+= b210*3*w*w*u;
		}

		[isolate]
		{
			const float3 b120= calc_b(P, N, 2, 1); //(2*P[2] + P[1] - delta*PN_w(2, 1)*N[2]) / 3.0f;
			E+= b120;
			out_P+= b120*3*w*u*u;
		}

		[isolate]
		{
			const float3 b021= calc_b(P, N, 2, 3); //(2*P[2] + P[3] - delta*PN_w(2, 3)*N[2]) / 3.0f;
			E+= b021;
			out_P+= b021*3*u*u*v;  	 
		}

		[isolate]
		{
			const float3 b012= calc_b(P, N, 3, 2); //(2*P[3] + P[2] - delta*PN_w(3, 2)*N[3]) / 3.0f;
			E+= b012;	
			out_P+= b012*3*u*v*v;		
		}

		[isolate]
		{
			const float3 b102= calc_b(P, N, 3, 1); //(2*P[3] + P[1] - delta*PN_w(3, 1)*N[3]) / 3.0f;
			E+= b102;
			out_P+= b102*3*w*v*v;
		}

		[isolate]
		{
			const float3 b201= calc_b(P, N, 1, 3); //(2*P[1] + P[3] - delta*PN_w(1, 3)*N[1]) / 3.0f;
			E+= b201;
			out_P+= b201*3*w*w*v; 
		}

		E/= 6.0f;	
		b111+= 1.5*E;
		out_P+= b111*6*w*u*v;

		return out_P;
	}
	#undef PN_w

	bool blend_cache_geometry_by_indices(
		in s_vertex_type_trilist_index indices,
		out s_shader_cache_vertex vertex,
		out float4 position)
	{		 
		[branch]
		if (is_degenerate_triangle(indices.index))
		{					
			vertex.position= 0;
			vertex.texcoord= 0;
			vertex.normal= 0;
			vertex.tangent= 0;
			vertex.binormal= 0;
			vertex.light_param= 0;
			position= k_vs_hidden_from_compiler;
			return false;
		}

		s_shader_cache_vertex vertex0, vertex1, vertex2;	
		fetch_cache_vertex_geometry(indices.index.x, vertex0);
		fetch_cache_vertex_geometry(indices.index.y, vertex1);
		fetch_cache_vertex_geometry(indices.index.z, vertex2);

		if (true)
		{
			// using NP patch tessellation
			float3 P[4];
			P[0]= 0;
			P[1]= vertex0.position.xyz;
			P[2]= vertex1.position.xyz;
			P[3]= vertex2.position.xyz;

			float3 N[4];
			N[0]= 0;
			N[1]= vertex0.normal;
			N[2]= vertex1.normal;
			N[3]= vertex2.normal;

			[isolate]
			{
				vertex.position= float4(PN_position_asm(P, N, indices.uvw), 1.f);
			}		
			vertex.normal= blend_float3(vertex0.normal, vertex1.normal, vertex2.normal, indices.uvw);		
		}
		else
		{
			// no NP patch tessellation
			[isolate]
			{
				vertex.position= float4(blend_float3(vertex0.position, vertex1.position, vertex2.position, indices.uvw), 1.f);
			}	
			vertex.normal= blend_float3(vertex0.normal, vertex1.normal, vertex2.normal, indices.uvw);
		}

		// add camera position back
		vertex.position.xyz+= Camera_Position;

		vertex.texcoord= blend_float2(vertex0.texcoord, vertex1.texcoord, vertex2.texcoord, indices.uvw);			
		vertex.tangent= blend_float3(vertex0.tangent, vertex1.tangent, vertex2.tangent, indices.uvw);	
		vertex.binormal= blend_float3(vertex0.binormal, vertex1.binormal, vertex2.binormal, indices.uvw);	

		vertex.light_param= blend_float4(vertex0.light_param, vertex1.light_param, vertex2.light_param, indices.uvw);	

		// transform postion from world to view
		position= mul(vertex.position, View_Projection);	

		return true;
	}

#endif //ONLY_TESS_LEVEL_2

#undef k_tess_cache_memexport_addr
#undef hidden_from_compiler
#endif //!pc
