//#line 2 "source\rasterizer\hlsl\blur_11_horizontal.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

LOCAL_SAMPLER_2D(target_sampler, 0);
//float4 kernel[11] : register(c2);		// c2 through c12 are the kernel (r,g,b)

fast4 default_ps(screen_output IN) : SV_Target
{
	float2 sample= IN.texcoord;
/*
	sample.x -= 5.0 * pixel_size.x;		// -5 through +5

	fast3 color= 0.0;
	for (int x= 0; x < 11; x++)
	{
		color += kernel[x].rgb * convert_from_bloom_buffer(sample2D(target_sampler, sample));
		sample.x += pixel_size.x;
	}
*/
	// solution using bilinear filtering:
	// actually this is a 10 wide blur - you get the 11th pixel by offsetting the vertical blur by half a pixel
	//
	// horizontal pass has the effect of shifting the center half a pixel to the left and down
	// vertical pass shifts it half a pixel up and right
	// result is an 11x11 gaussian blur that is perfectly centered
	//
	//   C = center pixel
	//   x = horizontal sample positions
	//   y = vertical sample positions
	//
	//
	//                      .---.---.
	//                      |   |   |
	//                      |---y---|
	//                      |   |   |
	//                      |---|---|
	//                      |   |   |
	//                      |---y---|
	//                      |   |   |
	//                      |---|---|
	//                      |   |   |
	//  .---.---.---.---.---|---y---|---.---.---. . .
	//  |   |   |   |   |   | C |   |   |   |   |   .
	//  '---|x--|---|x--|---x---|--x|---|--x|---| . .
	//  |   |   |   |   |   |   |   |   |   |   |   .
	//  '---'---'---'---'---'---y---'---'---'---' . .
	//                      |   |   |
	//                      |---|---|
	//                      |   |   |
	//                      |---y---|
	//                      |   |   |
	//                      '---'---'
	//						`   `   `
	//                      ' - ' - '
	//
	//
	// hard-coded kernel
	//
	//		[1  9]  [36  84]  [126  126]  [84  36]  [9  1]			/ 512
	//
	// Note:  with the half-pixel offset in the other direction, this kernel becomes:
	//
	//		1  10  45  120  210  252  210  120  45  10  1			/ 1024

	const float2 offset[5]=
		{
			{-4.0 - 1.0		/	(1.0+9.0),			0.5},			//  -4.1
			{-2.0 - 36.0	/	(36.0+84.0),		0.5},			//  -2.3
			{ 0.0 - 126.0	/	(126.0+126.0),		0.5},			//	-0.5
			{+2.0 - 84.0	/	(84.0+36.0),		0.5},			//  +1.3
			{+4.0 - 9.0		/	(1.0+9.0),			0.5}			//  +3.1
		};

	// Multiply by 2 ^ 3 to match Xenon tex2D data
	float4 color=	(1.0   + 9.0)	* sample2D(target_sampler, sample + offset[0] * pixel_size) * 8 +
					(36.0  + 84.0)	* sample2D(target_sampler, sample + offset[1] * pixel_size) * 8 +
					(126.0 + 126.0)	* sample2D(target_sampler, sample + offset[2] * pixel_size) * 8 +
					(84.0  + 36.0)	* sample2D(target_sampler, sample + offset[3] * pixel_size) * 8 +
					(1.0   + 9.0)	* sample2D(target_sampler, sample + offset[4] * pixel_size) * 8;

	color = color / 512.0;
	// The output surface/texture on Xenon has a range of 0-8 and an additional exponent bias of -2
	color = min(color * 4, 8); // like in Xenon render-target
	color = color / 32; // like in Xenon "Resolve" texture

	return color;
}
