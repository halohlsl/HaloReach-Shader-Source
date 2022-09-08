#if DX_VERSION == 9

VERTEX_CONSTANT(float4, rigid_node0, c16);
VERTEX_CONSTANT(float4, rigid_node1, c17);
VERTEX_CONSTANT(float4, rigid_node2, c18);
VERTEX_CONSTANT(float4,	Position_Compression_Scale, c12);
VERTEX_CONSTANT(float4,	Position_Compression_Offset, c13);

#elif DX_VERSION == 11

#define rigid_node0 Nodes[0][0]
#define rigid_node1 Nodes[0][1]
#define rigid_node2 Nodes[0][2]

#endif
