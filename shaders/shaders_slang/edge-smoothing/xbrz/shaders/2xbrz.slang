#version 450

/*
   Hyllian's xBR-vertex code and texel mapping
   
   Copyright (C) 2011/2016 Hyllian - sergiogdb@gmail.com

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is 
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
   THE SOFTWARE.

*/ 

// This shader also uses code and/or concepts from xBRZ as it appears
// in the Desmume source code. The license for which is as follows:

// ****************************************************************************
// * This file is part of the HqMAME project. It is distributed under         *
// * GNU General Public License: http://www.gnu.org/licenses/gpl-3.0          *
// * Copyright (C) Zenju (zenju AT gmx DOT de) - All Rights Reserved          *
// *                                                                          *
// * Additionally and as a special exception, the author gives permission     *
// * to link the code of this program with the MAME library (or with modified *
// * versions of MAME that use the same license as MAME), and distribute      *
// * linked combinations including the two. You must obey the GNU General     *
// * Public License in all respects for all of the code used other than MAME. *
// * If you modify this file, you may extend this exception to your version   *
// * of the file, but you are not obligated to do so. If you do not wish to   *
// * do so, delete this exception statement from your version.                *
// ****************************************************************************
	
#define BLEND_NONE 0
#define BLEND_NORMAL 1
#define BLEND_DOMINANT 2
#define LUMINANCE_WEIGHT 1.0
#define EQUAL_COLOR_TOLERANCE 30.0/255.0
#define STEEP_DIRECTION_THRESHOLD 2.2
#define DOMINANT_DIRECTION_THRESHOLD 3.6
#define M_PI 3.1415926535897932384626433832795

#define lerp(a,b,c) mix(a,b,c)

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

	const float  one_sixth = 1.0 / 6.0;
	const float  two_sixth = 2.0 / 6.0;
	const float four_sixth = 4.0 / 6.0;
	const float five_sixth = 5.0 / 6.0;

	float reduce(const vec3 color)
	{
		return dot(color, vec3(65536.0, 256.0, 1.0));
	}
	
	float DistYCbCr(const vec3 pixA, const vec3 pixB)
	{
		const vec3 w = vec3(0.2627, 0.6780, 0.0593);
		const float scaleB = 0.5 / (1.0 - w.b);
		const float scaleR = 0.5 / (1.0 - w.r);
		vec3 diff = pixA - pixB;
		float Y = dot(diff, w);
		float Cb = scaleB * (diff.b - Y);
		float Cr = scaleR * (diff.r - Y);
		
		return sqrt( ((LUMINANCE_WEIGHT * Y) * (LUMINANCE_WEIGHT * Y)) + (Cb * Cb) + (Cr * Cr) );
	}
	
	bool IsPixEqual(const vec3 pixA, const vec3 pixB)
	{
		return (DistYCbCr(pixA, pixB) < EQUAL_COLOR_TOLERANCE);
	}
	
	bool IsBlendingNeeded(const ivec4 blend)
	{
		return any(notEqual(blend, ivec4(BLEND_NONE)));
	}
	
	void ScalePixel(const ivec4 blend, const vec3 k[9], inout vec3 dst[4])
{
	float v0 = reduce(k[0]);
	float v4 = reduce(k[4]);
	float v5 = reduce(k[5]);
	float v7 = reduce(k[7]);
	float v8 = reduce(k[8]);
		
	float dist_01_04 = DistYCbCr(k[1], k[4]);
	float dist_03_08 = DistYCbCr(k[3], k[8]);
	bool haveShallowLine = (STEEP_DIRECTION_THRESHOLD * dist_01_04 <= dist_03_08) && (v0 != v4) && (v5 != v4);
	bool haveSteepLine   = (STEEP_DIRECTION_THRESHOLD * dist_03_08 <= dist_01_04) && (v0 != v8) && (v7 != v8);
	bool needBlend = (blend[2] != BLEND_NONE);
	bool doLineBlend = (  blend[2] >= BLEND_DOMINANT ||
				       !((blend[1] != BLEND_NONE && !IsPixEqual(k[0], k[4])) ||
				         (blend[3] != BLEND_NONE && !IsPixEqual(k[0], k[8])) ||
				         (IsPixEqual(k[4], k[3]) && IsPixEqual(k[3], k[2]) && IsPixEqual(k[2], k[1]) && IsPixEqual(k[1], k[8]) && !IsPixEqual(k[0], k[2])) ) );
		
	vec3 blendPix = ( DistYCbCr(k[0], k[1]) <= DistYCbCr(k[0], k[3]) ) ? k[1] : k[3];
	dst[1] = lerp(dst[1], blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.25 : 0.00);
	dst[2] = lerp(dst[2], blendPix, (needBlend) ? ((doLineBlend) ? ((haveShallowLine) ? ((haveSteepLine) ? 5.0/6.0 : 0.75) : ((haveSteepLine) ? 0.75 : 0.50)) : 1.0 - (M_PI/4.0)) : 0.00);
	dst[3] = lerp(dst[3], blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.25 : 0.00);
   }
	
	//---------------------------------------
	// Input Pixel Mapping:  --|21|22|23|--
	//                       19|06|07|08|09
	//                       18|05|00|01|10
	//                       17|04|03|02|11
	//                       --|15|14|13|--
	//
	// Output Pixel Mapping:     00|01
	//                           03|02

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec4 t1;
layout(location = 2) out vec4 t2;
layout(location = 3) out vec4 t3;
layout(location = 4) out vec4 t4;
layout(location = 5) out vec4 t5;
layout(location = 6) out vec4 t6;
layout(location = 7) out vec4 t7;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
   
vec2 ps = vec2(params.SourceSize.z, params.SourceSize.w);
float dx = ps.x;
float dy = ps.y;

  //  A1 B1 C1
// A0 A  B  C C4
// D0 D  E  F F4
// G0 G  H  I I4
  //  G5 H5 I5

t1 = vTexCoord.xxxy + vec4( -dx, 0.0, dx,-2.0*dy); // A1 B1 C1
t2 = vTexCoord.xxxy + vec4( -dx, 0.0, dx, -dy); // A B C
t3 = vTexCoord.xxxy + vec4( -dx, 0.0, dx, 0.0); // D E F
t4 = vTexCoord.xxxy + vec4( -dx, 0.0, dx, dy); // G H I
t5 = vTexCoord.xxxy + vec4( -dx, 0.0, dx, 2.0*dy); // G5 H5 I5
t6 = vTexCoord.xyyy + vec4(-2.0*dx,-dy, 0.0, dy); // A0 D0 G0
t7 = vTexCoord.xyyy + vec4( 2.0*dx,-dy, 0.0, dy); // C4 F4 I4
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec4 t1;
layout(location = 2) in vec4 t2;
layout(location = 3) in vec4 t3;
layout(location = 4) in vec4 t4;
layout(location = 5) in vec4 t5;
layout(location = 6) in vec4 t6;
layout(location = 7) in vec4 t7;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
	//---------------------------------------
	// Input Pixel Mapping:  20|21|22|23|24
	//                       19|06|07|08|09
	//                       18|05|00|01|10
	//                       17|04|03|02|11
	//                       16|15|14|13|12
  
	vec3 src[25];
  
	src[21] = texture(Source, t1.xw).rgb;
	src[22] = texture(Source, t1.yw).rgb;
	src[23] = texture(Source, t1.zw).rgb;
	src[ 6] = texture(Source, t2.xw).rgb;
	src[ 7] = texture(Source, t2.yw).rgb;
	src[ 8] = texture(Source, t2.zw).rgb;
	src[ 5] = texture(Source, t3.xw).rgb;
	src[ 0] = texture(Source, t3.yw).rgb;
	src[ 1] = texture(Source, t3.zw).rgb;
	src[ 4] = texture(Source, t4.xw).rgb;
	src[ 3] = texture(Source, t4.yw).rgb;
	src[ 2] = texture(Source, t4.zw).rgb;
	src[15] = texture(Source, t5.xw).rgb;
	src[14] = texture(Source, t5.yw).rgb;
	src[13] = texture(Source, t5.zw).rgb;
	src[19] = texture(Source, t6.xy).rgb;
	src[18] = texture(Source, t6.xz).rgb;
	src[17] = texture(Source, t6.xw).rgb;
	src[ 9] = texture(Source, t7.xy).rgb;
	src[10] = texture(Source, t7.xz).rgb;
	src[11] = texture(Source, t7.xw).rgb;
	
		float v[9];
		v[0] = reduce(src[0]);
		v[1] = reduce(src[1]);
		v[2] = reduce(src[2]);
		v[3] = reduce(src[3]);
		v[4] = reduce(src[4]);
		v[5] = reduce(src[5]);
		v[6] = reduce(src[6]);
		v[7] = reduce(src[7]);
		v[8] = reduce(src[8]);
		
		ivec4 blendResult = ivec4(BLEND_NONE);
		
		// Preprocess corners
		// Pixel Tap Mapping: --|--|--|--|--
		//                    --|--|07|08|--
		//                    --|05|00|01|10
		//                    --|04|03|02|11
		//                    --|--|14|13|--
		// Corner (1, 1)
		if ( ((v[0] == v[1] && v[3] == v[2]) || (v[0] == v[3] && v[1] == v[2])) == false)
		{
			float dist_03_01 = DistYCbCr(src[ 4], src[ 0]) + DistYCbCr(src[ 0], src[ 8]) + DistYCbCr(src[14], src[ 2]) + DistYCbCr(src[ 2], src[10]) + (4.0 * DistYCbCr(src[ 3], src[ 1]));
			float dist_00_02 = DistYCbCr(src[ 5], src[ 3]) + DistYCbCr(src[ 3], src[13]) + DistYCbCr(src[ 7], src[ 1]) + DistYCbCr(src[ 1], src[11]) + (4.0 * DistYCbCr(src[ 0], src[ 2]));
			bool dominantGradient = (DOMINANT_DIRECTION_THRESHOLD * dist_03_01) < dist_00_02;
			blendResult[2] = ((dist_03_01 < dist_00_02) && (v[0] != v[1]) && (v[0] != v[3])) ? ((dominantGradient) ? BLEND_DOMINANT : BLEND_NORMAL) : BLEND_NONE;
		}

		// Pixel Tap Mapping: --|--|--|--|--
		//                    --|06|07|--|--
		//                    18|05|00|01|--
		//                    17|04|03|02|--
		//                    --|15|14|--|--
		// Corner (0, 1)
		if ( ((v[5] == v[0] && v[4] == v[3]) || (v[5] == v[4] && v[0] == v[3])) == false)
		{
			float dist_04_00 = DistYCbCr(src[17], src[ 5]) + DistYCbCr(src[ 5], src[ 7]) + DistYCbCr(src[15], src[ 3]) + DistYCbCr(src[ 3], src[ 1]) + (4.0 * DistYCbCr(src[ 4], src[ 0]));
			float dist_05_03 = DistYCbCr(src[18], src[ 4]) + DistYCbCr(src[ 4], src[14]) + DistYCbCr(src[ 6], src[ 0]) + DistYCbCr(src[ 0], src[ 2]) + (4.0 * DistYCbCr(src[ 5], src[ 3]));
			bool dominantGradient = (DOMINANT_DIRECTION_THRESHOLD * dist_05_03) < dist_04_00;
			blendResult[3] = ((dist_04_00 > dist_05_03) && (v[0] != v[5]) && (v[0] != v[3])) ? ((dominantGradient) ? BLEND_DOMINANT : BLEND_NORMAL) : BLEND_NONE;
		}
		
		// Pixel Tap Mapping: --|--|22|23|--
		//                    --|06|07|08|09
		//                    --|05|00|01|10
		//                    --|--|03|02|--
		//                    --|--|--|--|--
		// Corner (1, 0)
		if ( ((v[7] == v[8] && v[0] == v[1]) || (v[7] == v[0] && v[8] == v[1])) == false)
		{
			float dist_00_08 = DistYCbCr(src[ 5], src[ 7]) + DistYCbCr(src[ 7], src[23]) + DistYCbCr(src[ 3], src[ 1]) + DistYCbCr(src[ 1], src[ 9]) + (4.0 * DistYCbCr(src[ 0], src[ 8]));
			float dist_07_01 = DistYCbCr(src[ 6], src[ 0]) + DistYCbCr(src[ 0], src[ 2]) + DistYCbCr(src[22], src[ 8]) + DistYCbCr(src[ 8], src[10]) + (4.0 * DistYCbCr(src[ 7], src[ 1]));
			bool dominantGradient = (DOMINANT_DIRECTION_THRESHOLD * dist_07_01) < dist_00_08;
			blendResult[1] = ((dist_00_08 > dist_07_01) && (v[0] != v[7]) && (v[0] != v[1])) ? ((dominantGradient) ? BLEND_DOMINANT : BLEND_NORMAL) : BLEND_NONE;
		}
		
		// Pixel Tap Mapping: --|21|22|--|--
		//                    19|06|07|08|--
		//                    18|05|00|01|--
		//                    --|04|03|--|--
		//                    --|--|--|--|--
		// Corner (0, 0)
		if ( ((v[6] == v[7] && v[5] == v[0]) || (v[6] == v[5] && v[7] == v[0])) == false)
		{
			float dist_05_07 = DistYCbCr(src[18], src[ 6]) + DistYCbCr(src[ 6], src[22]) + DistYCbCr(src[ 4], src[ 0]) + DistYCbCr(src[ 0], src[ 8]) + (4.0 * DistYCbCr(src[ 5], src[ 7]));
			float dist_06_00 = DistYCbCr(src[19], src[ 5]) + DistYCbCr(src[ 5], src[ 3]) + DistYCbCr(src[21], src[ 7]) + DistYCbCr(src[ 7], src[ 1]) + (4.0 * DistYCbCr(src[ 6], src[ 0]));
			bool dominantGradient = (DOMINANT_DIRECTION_THRESHOLD * dist_05_07) < dist_06_00;
			blendResult[0] = ((dist_05_07 < dist_06_00) && (v[0] != v[5]) && (v[0] != v[7])) ? ((dominantGradient) ? BLEND_DOMINANT : BLEND_NORMAL) : BLEND_NONE;
		}
		
		vec3 dst[4];
		dst[ 0] = src[0];
		dst[ 1] = src[0];
		dst[ 2] = src[0];
		dst[ 3] = src[0];
		
		// Scale pixel
		if (IsBlendingNeeded(blendResult) == true)
		{
	   vec3 k[9];
		vec3 tempDst3;
		
		k[0] = src[0];
		k[1] = src[1];
		k[2] = src[2];
		k[3] = src[3];
		k[4] = src[4];
		k[5] = src[5];
		k[6] = src[6];
		k[7] = src[7];
		k[8] = src[8];
		ScalePixel(blendResult.xyzw, k, dst);
		
		k[1] = src[7];
		k[2] = src[8];
		k[3] = src[1];
		k[4] = src[2];
		k[5] = src[3];
		k[6] = src[4];
		k[7] = src[5];
		k[8] = src[6];
		tempDst3 = dst[3];
		dst[3] = dst[2];
		dst[2] = dst[1];
		dst[1] = dst[0];
		dst[0] = tempDst3;
		ScalePixel(blendResult.wxyz, k, dst);
		
		k[1] = src[5];
		k[2] = src[6];
		k[3] = src[7];
		k[4] = src[8];
		k[5] = src[1];
		k[6] = src[2];
		k[7] = src[3];
		k[8] = src[4];
		tempDst3 = dst[3];
		dst[3] = dst[2];
		dst[2] = dst[1];
		dst[1] = dst[0];
		dst[0] = tempDst3;
		ScalePixel(blendResult.zwxy, k, dst);
		
		k[1] = src[3];
		k[2] = src[4];
		k[3] = src[5];
		k[4] = src[6];
		k[5] = src[7];
		k[6] = src[8];
		k[7] = src[1];
		k[8] = src[2];
		tempDst3 = dst[3];
		dst[3] = dst[2];
		dst[2] = dst[1];
		dst[1] = dst[0];
		dst[0] = tempDst3;
		ScalePixel(blendResult.yzwx, k, dst);
		
		// Rotate the destination pixels back to 0 degrees.
		tempDst3 = dst[3];
		dst[3] = dst[2];
		dst[2] = dst[1];
		dst[1] = dst[0];
		dst[0] = tempDst3;
		}
		
	vec2 f = step(0.5, fract(vTexCoord*params.SourceSize.xy));
	vec3 res = lerp( lerp(dst[0], dst[1], f.x),
	                        lerp(dst[3], dst[2], f.x), f.y );
								 
   FragColor = vec4(res, 1.0);
}
