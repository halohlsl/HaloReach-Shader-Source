/*
LIGHTMAP_SAMPLING.FX
Copyright (c) Microsoft Corporation, 2007. all rights reserved.
2/3/2007 3:24:00 PM (haochen)
	shared code for sampling light probe texture

8 Jul 2008   14:22 BUNGIE\yaohhu :
    add dual_vmf support
    
    float4 vmf[4]
    0: xyz: direction for vmf0
       a: analytical mask. ( how much is visible )
       
    1: rgb: color for vmf0
       a: bandwidth for vmf0. ( the higher, the sharper )
       
    2: xyz: dir for vmf1
       a: cloud mask. ( how much should cloud affect it. it is used in the case of blending vmf and analytical light for object lighting )
       
    3: rgb: color
       a: bandwidth
    
*/

#ifndef pc


sampler g_direction_lut;

void normalvmfTextureFetch(out float visibility_mask, out float4 tex[4],float2 vTexCoord1)
{
    float3 lightmap_texcoord_bottom= float3(vTexCoord1, 0.0f);

    float4 mask;
    asm{ tfetch2D mask, vTexCoord1, lightprobe_dir_and_bandwidth_ps, MipFilter =point };
    visibility_mask= mask.a;
    
    asm{ tfetch3D tex[0], lightmap_texcoord_bottom, lightprobe_hdr_color_ps, OffsetZ= 0.5,VolMinFilter =point,VolMagFilter=point,MipFilter =point  };
    asm{ tfetch3D tex[1], lightmap_texcoord_bottom, lightprobe_hdr_color_ps, OffsetZ= 1.5,VolMinFilter =point,VolMagFilter=point,MipFilter =point  };
    asm{ tfetch3D tex[2], lightmap_texcoord_bottom, lightprobe_hdr_color_ps, OffsetZ= 2.5,VolMinFilter =point,VolMagFilter=point,MipFilter =point };
    tex[3].rgb= 0;
    tex[3].a= mask.r;
}


void DecompressVMF(out float4 vmf[4],in float4 tex[4], in float visibility_mask)
{
    vmf[0].rgb= float3(tex[0].a, tex[1].a, tex[2].a)*2-1;
    vmf[1].a= length(vmf[0].rgb);
    
    vmf[0].rgb= vmf[0].rgb/vmf[1].a;
    
    float fIntensity= exp(-6.238325*(tex[3].a));
    
    float3 Colors[2]={tex[0].rgb+tex[1].rgb*2-1,tex[2].rgb};
    
    vmf[1].rgb=Colors[0]*p_lightmap_compress_constant_0.x*fIntensity;
    vmf[3].rgb=Colors[1]*p_lightmap_compress_constant_0.x*fIntensity;    
   
    // see top for comments
    vmf[0].a= visibility_mask; // analytical mask
    vmf[2].xyz= 0;
    vmf[2].a= 1; // cloud mask
    vmf[3].a=0;  
}

#endif


void sample_lightprobe_texture(
	in float2 lightmap_texcoord,
	out float4 vmf_coefficients[4])
{
	vmf_coefficients[0]= 1.0f;
	vmf_coefficients[1]= 0.0f;
	vmf_coefficients[2]= 0.0f;
	vmf_coefficients[3]= 0.0f;

#ifndef pc

    float4 tex[4];
    float visibility_mask;

	normalvmfTextureFetch(visibility_mask, tex,lightmap_texcoord);
    
    DecompressVMF(vmf_coefficients,tex, visibility_mask);
    
	
#endif //pc
	
}


#ifndef pc

void decompress_per_vertex_lighting_data(
    in float4 vmf_light0, 
    in float4 vmf_light1, 
    out float4 vmf0, 
    out float4 vmf1, 
    out float4 vmf2, 
    out float4 vmf3)
{
    float4 direction;
   
    float2 dir_coord=float2(fmod(vmf_light0.x, 128), 0);
    asm{ tfetch2D direction, dir_coord, g_direction_lut, UnnormalizedTextureCoords= true, MagFilter =point, MinFilter= point, OffsetX= 0.5, UseComputedLOD= false};
    
    int analytical_mask_0= (vmf_light0.x-fmod(vmf_light0.x,128))/128;
    int analytical_mask_1= fmod(vmf_light0.y,2);
    
    int dc_color_0= vmf_light0.y-fmod(vmf_light0.y,2);
    dc_color_0/=2;
    int dc_r= fmod(dc_color_0,32);
    int dc_g= dc_color_0-fmod(dc_color_0,32);
    dc_g/=32;
    
    int dc_color_1= fmod(vmf_light0.z,8);
    dc_g+=dc_color_1*4;
    
    int dc_b= (vmf_light0.z-dc_color_1)/8;
        
    vmf0= direction;
    
    vmf1.xyz= float3(vmf_light0.w, vmf_light1.xy)/255;
    vmf1.xyz*=vmf1.xyz*per_vertex_lighting_offset.y;    
    
    vmf3.xyz= float3(dc_r, dc_g, dc_b)/31;
    vmf3.xyz*=vmf3.xyz*per_vertex_lighting_offset.y;

    vmf0.w= (analytical_mask_1*2+analytical_mask_0)/3.0f;
    vmf0.w*=vmf0.w;
    
    vmf1.w= 1;
    vmf2= float4(0,0,0,1);
    vmf3.w= 1;
}

void fetch_stream(
	int vertex_index_after_offset,
	out float4 vmf_light0,
	out float4 vmf_light1)
{
    float4 seg0, seg1;

   int part1= vertex_index_after_offset*1.5f;
   asm {
      vfetch    seg0, part1, texcoord3                 // grab four PRT samples
   };    
   int part2= part1+1;
    
   asm {
      vfetch    seg1, part2, texcoord3                 // grab four PRT samples
   };    
   [branch]
   if (fmod(vertex_index_after_offset,2))
   {
     vmf_light0.xyzw=float4(seg0.yx,seg1.wz);
     vmf_light1.xyzw=seg1.yxwz;
   }
   else
   {
     vmf_light0.xyzw=seg0.wzyx;
     vmf_light1.xyzw=seg1.wzyx;
   }
	vmf_light1.zw= 0;
}
#endif //pc



#ifdef pc

#define vertex_index 0

void fetch_stream(
	int vertex_index_after_offset,
	out float4 vmf_light0,
	out float4 vmf_light1)
{
	vmf_light0= vmf_light1= 0;
}

void decompress_per_vertex_lighting_data(
    in float4 vmf_light0, 
    in float4 vmf_light1, 
    out float4 vmf0, 
    out float4 vmf1, 
    out float4 vmf2, 
    out float4 vmf3)
{
	vmf0= vmf1= vmf2= vmf3= 0;
}

#endif 

