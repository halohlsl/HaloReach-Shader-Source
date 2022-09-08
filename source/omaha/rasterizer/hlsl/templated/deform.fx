#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"

float3 transform_point(in float4 position, in float4 node[3])
{
	float3 result;

	result.x= dot(position, node[0]);
	result.y= dot(position, node[1]);
	result.z= dot(position, node[2]);

	return result;
}

float3 transform_vector(in float3 vect, in float4 node[3])
{
	float3 result;

	result.x= dot(vect, node[0].xyz);
	result.y= dot(vect, node[1].xyz);
	result.z= dot(vect, node[2].xyz);

	return result;
}

void deform_flat_world(
	inout s_world_vertex vertex,
	out float4 local_to_world_transform[3])
{
	local_to_world_transform[0]= float4(1, 0, 0, 0);
	local_to_world_transform[1]= float4(0, 1, 0, 0);
	local_to_world_transform[2]= float4(0, 0, 1, 0);
}

void deform_world(
	inout s_world_vertex vertex,
	out float4 local_to_world_transform[3])
{
	deform_flat_world(vertex, local_to_world_transform);
}

void deform_flat_rigid(
	inout s_rigid_vertex vertex,
	out float4 local_to_world_transform[3])
{
	float4 position;

	local_to_world_transform= Nodes[0];
//	local_to_world_transform[0].xyz= float3(1.0f, 0.0f, 0.0f);
//	local_to_world_transform[1].xyz= float3(0.0f, 1.0f, 0.0f);
//	local_to_world_transform[2].xyz= float3(0.0f, 0.0f, 1.0f);

	position.xyz= vertex.position.xyz*Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;
	position.w= 1.0f;
	vertex.texcoord= vertex.texcoord*UV_Compression_Scale_Offset.xy + UV_Compression_Scale_Offset.zw;

	[isolate]
	{
		vertex.position= float4(transform_point(position, local_to_world_transform), vertex.position.w);
	}
}

void deform_rigid(
	inout s_rigid_vertex vertex,
	out float4 local_to_world_transform[3])
{
	deform_flat_rigid(vertex, local_to_world_transform);

	vertex.normal= transform_vector(vertex.normal,local_to_world_transform);
	//vertex.binormal= transform_vector(vertex.binormal, local_to_world_transform);
	vertex.tangent= transform_vector(vertex.tangent, local_to_world_transform);

	vertex.normal= normalize(vertex.normal);
	//vertex.binormal= normalize(vertex.binormal);
	vertex.tangent= normalize(vertex.tangent);
}

void deform_flat_skinned(
	inout s_skinned_vertex vertex,
	out float4 local_to_world_transform[3])
{
	float4 source_pos;
	float sum_of_weights= dot(vertex.node_weights.xyzw, 1.0f);

	// normalize the node weights so that they sum to 1
	vertex.node_weights= vertex.node_weights/sum_of_weights;

	vertex.position.xyz= vertex.position.xyz*Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;
	vertex.texcoord= vertex.texcoord*UV_Compression_Scale_Offset.xy + UV_Compression_Scale_Offset.zw;

	source_pos= float4(vertex.position.xyz, 1.0f);

	local_to_world_transform[0]= Nodes[vertex.node_indices.x][0] * vertex.node_weights.x +
							Nodes[vertex.node_indices.y][0] * vertex.node_weights.y +
							Nodes[vertex.node_indices.z][0] * vertex.node_weights.z +
							Nodes[vertex.node_indices.w][0] * vertex.node_weights.w;

	local_to_world_transform[1]= Nodes[vertex.node_indices.x][1] * vertex.node_weights.x +
							Nodes[vertex.node_indices.y][1] * vertex.node_weights.y +
							Nodes[vertex.node_indices.z][1] * vertex.node_weights.z +
							Nodes[vertex.node_indices.w][1] * vertex.node_weights.w;

	local_to_world_transform[2]= Nodes[vertex.node_indices.x][2] * vertex.node_weights.x +
							Nodes[vertex.node_indices.y][2] * vertex.node_weights.y +
							Nodes[vertex.node_indices.z][2] * vertex.node_weights.z +
							Nodes[vertex.node_indices.w][2] * vertex.node_weights.w;

	[isolate]
	{
		vertex.position= float4(transform_point(source_pos, local_to_world_transform), vertex.position.w);
	}
}

void deform_skinned(
	inout s_skinned_vertex vertex,
	out float4 local_to_world_transform[3])
{
	deform_flat_skinned(vertex, local_to_world_transform);

	vertex.normal= transform_vector(vertex.normal, local_to_world_transform);
	//vertex.binormal= transform_vector(vertex.binormal, local_to_world_transform);
	vertex.tangent= transform_vector(vertex.tangent,local_to_world_transform);

//	vertex.position= vertex.node_weights.x*transform_point(source_pos, Nodes[vertex.node_indices.x]);
//	vertex.position+= vertex.node_weights.y*transform_point(source_pos, Nodes[vertex.node_indices.y]);
//	vertex.position+= vertex.node_weights.z*transform_point(source_pos, Nodes[vertex.node_indices.z]);
//	vertex.position+= vertex.node_weights.w*transform_point(source_pos, Nodes[vertex.node_indices.w]);

//	vertex.normal= transform_vector(vertex.normal, Nodes[vertex.node_indices[0]]);
//	vertex.binormal= transform_vector(vertex.binormal, Nodes[vertex.node_indices[0]]);
//	vertex.tangent= transform_vector(vertex.tangent, Nodes[vertex.node_indices[0]]);

	vertex.normal= normalize(vertex.normal);
	//vertex.binormal= normalize(vertex.binormal);
	vertex.tangent= normalize(vertex.tangent);
}

void deform_object_imposter(
	inout s_object_imposter_vertex vertex,
	out float4 local_to_world_transform[3])
{
	float4 source_pos;
#if defined(xenon) || (DX_VERSION == 11)
	int node_index= (k_bool_render_rigid_imposter)? 0 : (vertex.position.w+(1.f/512.f))*255.f; // decompress node index from last byte
#else
	int node_index= 0;
#endif //xenon/pc

	vertex.position.xyz= vertex.position.xyz*Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;
	source_pos= float4(vertex.position.x, vertex.position.y, vertex.position.z, 1.0f);

	local_to_world_transform= Nodes[node_index];

	vertex.position.xyz= transform_point(source_pos, Nodes[node_index]);
	vertex.normal= transform_vector(vertex.normal, Nodes[node_index]);
	vertex.normal= normalize(vertex.normal);
}

void deform_decorator(
	inout s_decorator_vertex vertex,
	out float4 local_to_world_transform[3])
{
	// not used - see explicit transform in decorator render shader
}


void deform_tiny_position(
	inout s_tiny_position_vertex vertex,
	out float4 local_to_world_transform[3])
{
	// basically exactly the same as deform_rigid, but only acting on position

	float4 position;

	local_to_world_transform= Nodes[0];

	position.xyz= vertex.position.xyz * Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;
	position.w= 1.0f;

	[isolate]
	{
		vertex.position= float4(transform_point(position, local_to_world_transform), 1.f);
	}
}


void deform_tiny_position_projective(
	inout s_tiny_position_vertex vertex,
	out float4 local_to_world_transform[3])
{
	// basically exactly the same as deform_rigid, but only acting on position

	float4 position;

	local_to_world_transform= Nodes[0];

	position.xyz= vertex.position * Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;
	position.yz *= position.x;		// x is forward vector, scales yz
	position.w= 1.0f;

	[isolate]
	{
		vertex.position= float4(transform_point(position, local_to_world_transform), 1.f);
	}
}

void deform_world_tessellated(
	inout s_world_tessellated_vertex vertex,
	out float4 local_to_world_transform[3])
{
	// not used
	local_to_world_transform[0]= float4(1, 0, 0, 0);
	local_to_world_transform[1]= float4(0, 1, 0, 0);
	local_to_world_transform[2]= float4(0, 0, 1, 0);
}

void deform_rigid_tessellated(
	inout s_rigid_tessellated_vertex vertex,
	out float4 local_to_world_transform[3])
{
	// not used
	local_to_world_transform[0]= float4(1, 0, 0, 0);
	local_to_world_transform[1]= float4(0, 1, 0, 0);
	local_to_world_transform[2]= float4(0, 0, 1, 0);
}

void deform_skinned_tessellated(
	inout s_skinned_tessellated_vertex vertex,
	out float4 local_to_world_transform[3])
{
	// not used
	local_to_world_transform[0]= float4(1, 0, 0, 0);
	local_to_world_transform[1]= float4(0, 1, 0, 0);
	local_to_world_transform[2]= float4(0, 0, 1, 0);
}

void deform_shader_cache(
	inout s_shader_cache_vertex vertex,
	out float4 local_to_world_transform[3])
{
	// not used
	local_to_world_transform[0]= float4(1, 0, 0, 0);
	local_to_world_transform[1]= float4(0, 1, 0, 0);
	local_to_world_transform[2]= float4(0, 0, 1, 0);
}

#if !IS_VERTEX_TYPE(s_object_imposter_vertex)
#if !IS_VERTEX_TYPE(s_tiny_position_vertex)

// Workaround for z-fighting problem...
// Calculation of output interpolator "position" must be completely segregated from the
// rest of the calculation by a scope with a runtime test.  DO NOT USE "position" for
// anything after this call, other than a return value from the shader!
void always_local_to_view(
	inout vertex_type vertex,
	out float4 local_to_world_transform[3],
	out float4 position,
	out float3 binormal)
{
	float binormal_scale= (vertex.position.w*2.f)-1.f;

    local_to_world_transform[0]=0;
    local_to_world_transform[1]=0;
    local_to_world_transform[2]=0;

	deform(vertex, local_to_world_transform);

	// derive binormal from normal and tangent plus a flag in position.w
	binormal= cross(vertex.normal, vertex.tangent);
	binormal= mul(binormal, binormal_scale);
	binormal= safe_normalize(binormal);

	position= mul(float4(vertex.position.xyz, 1.0f), View_Projection);

}

void always_local_to_view_fast(
	inout vertex_type vertex,
	out float4 local_to_world_transform[3],
	out float4 position)
{
    local_to_world_transform[0]=0;
    local_to_world_transform[1]=0;
    local_to_world_transform[2]=0;

	deform(vertex, local_to_world_transform);

	position= mul(float4(vertex.position.xyz, 1.0f), View_Projection);
}

#endif // !tiny position vert
#endif // !object imposter vert
