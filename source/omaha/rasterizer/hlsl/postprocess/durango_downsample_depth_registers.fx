#if DX_VERSION == 11

CBUFFER_BEGIN(DurangoDownsampleDepthCS)
	CBUFFER_CONST(DurangoDownsampleDepthCS,		float,		half_res_zminmax_dither_threshold,	k_cs_durango_downsample_depth_half_res_zminmax_dither_threshold)
	CBUFFER_CONST(DurangoDownsampleDepthCS,		uint,		out_htile_info,						k_cs_durango_downsample_depth_out_htile_info)
CBUFFER_END

COMPUTE_TEXTURE(_2D, 	source_depth_texture, 		k_cs_durango_downsample_depth_source_texture, 		0)
RW_COMPUTE_TEXTURE(_2D, destination_depth_texture, 	k_cs_durango_downsample_depth_destination_texture, 	0)
RW_BYTE_ADDRESS_BUFFER(destination_htile,			k_cs_durango_downsample_depth_destination_htile, 	1)

#endif
