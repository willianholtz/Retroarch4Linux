#version 450

/*
   Hyllian's jinc windowed-jinc 2-lobe sharper with anti-ringing Shader
   
   Copyright (C) 2011-2014 Hyllian/Jararaca - sergiogdb@gmail.com

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float JINC2_WINDOW_SINC;
	float JINC2_SINC;
	float JINC2_AR_STRENGTH;
} params;

#pragma parameter JINC2_WINDOW_SINC "Window Sinc Param" 0.50 0.0 1.0 0.01
#pragma parameter JINC2_SINC "Sinc Param" 0.88 0.0 1.0 0.01
#pragma parameter JINC2_AR_STRENGTH "Anti-ringing Strength" 0.0 0.0 1.0 0.1

#define mul(a,b) (b*a)

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

      /*
         This is an approximation of Jinc(x)*Jinc(x*r1/r2) for x < 2.5,
         where r1 and r2 are the first two zeros of jinc function.
         For a jinc 2-lobe best approximation, use A=0.5 and B=0.825.
      */  

// A=0.5, B=0.825 is the best jinc approximation for x<2.5. if B=1.0, it's a lanczos filter.
// Increase A to get more blur. Decrease it to get a sharper picture. 
// B = 0.825 to get rid of dithering. Increase B to get a fine sharpness, though dithering returns.

#define halfpi  1.5707963267948966192313216916398
#define pi    3.1415926535897932384626433832795
#define wa    (params.JINC2_WINDOW_SINC*pi)
#define wb    (params.JINC2_SINC*pi)

const vec3 Y = vec3(0.299, 0.587, 0.114);

float df(float A, float B)
{
	return abs(A-B);
}

// Calculates the distance between two points
float d(vec2 pt1, vec2 pt2)
{
  vec2 v = pt2 - pt1;
  return sqrt(dot(v,v));
}

vec3 min4(vec3 a, vec3 b, vec3 c, vec3 d)
{
    return min(a, min(b, min(c, d)));
}
vec3 max4(vec3 a, vec3 b, vec3 c, vec3 d)
{
    return max(a, max(b, max(c, d)));
}

vec4 resampler(vec4 x)
{
	vec4 res;

   res.x = (x.x==0.0) ?  (wa*wb)  :  sin(x.x*wa)*sin(x.x*wb)/(x.x*x.x);
   res.y = (x.y==0.0) ?  (wa*wb)  :  sin(x.y*wa)*sin(x.y*wb)/(x.y*x.y);
   res.z = (x.z==0.0) ?  (wa*wb)  :  sin(x.z*wa)*sin(x.z*wb)/(x.z*x.z);
   res.w = (x.w==0.0) ?  (wa*wb)  :  sin(x.w*wa)*sin(x.w*wb)/(x.w*x.w);
      
	return res;
}

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.0001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
      vec3 color;
      mat4x4 weights;

      vec2 dx = vec2(1.0, 0.0);
      vec2 dy = vec2(0.0, 1.0);

      vec2 pc = vTexCoord * params.SourceSize.xy;

      vec2 tc = (floor(pc-vec2(0.5,0.5))+vec2(0.5,0.5));
     
      weights[0] = resampler(vec4(d(pc, tc    -dx    -dy), d(pc, tc           -dy), d(pc, tc    +dx    -dy), d(pc, tc+2.0*dx    -dy)));
      weights[1] = resampler(vec4(d(pc, tc    -dx       ), d(pc, tc              ), d(pc, tc    +dx       ), d(pc, tc+2.0*dx       )));
      weights[2] = resampler(vec4(d(pc, tc    -dx    +dy), d(pc, tc           +dy), d(pc, tc    +dx    +dy), d(pc, tc+2.0*dx    +dy)));
      weights[3] = resampler(vec4(d(pc, tc    -dx+2.0*dy), d(pc, tc       +2.0*dy), d(pc, tc    +dx+2.0*dy), d(pc, tc+2.0*dx+2.0*dy)));

      //weights[0][0] = weights[0][3] = weights[3][0] = weights[3][3] = 0.0;

      dx = dx / params.SourceSize.xy;
      dy = dy / params.SourceSize.xy;
      tc = tc / params.SourceSize.xy;
     
     // reading the texels
     
      vec3 c00 = texture(Source, tc    -dx    -dy).xyz;
      vec3 c10 = texture(Source, tc           -dy).xyz;
      vec3 c20 = texture(Source, tc    +dx    -dy).xyz;
      vec3 c30 = texture(Source, tc+2.0*dx    -dy).xyz;
      vec3 c01 = texture(Source, tc    -dx       ).xyz;
      vec3 c11 = texture(Source, tc              ).xyz;
      vec3 c21 = texture(Source, tc    +dx       ).xyz;
      vec3 c31 = texture(Source, tc+2.0*dx       ).xyz;
      vec3 c02 = texture(Source, tc    -dx    +dy).xyz;
      vec3 c12 = texture(Source, tc           +dy).xyz;
      vec3 c22 = texture(Source, tc    +dx    +dy).xyz;
      vec3 c32 = texture(Source, tc+2.0*dx    +dy).xyz;
      vec3 c03 = texture(Source, tc    -dx+2.0*dy).xyz;
      vec3 c13 = texture(Source, tc       +2.0*dy).xyz;
      vec3 c23 = texture(Source, tc    +dx+2.0*dy).xyz;
      vec3 c33 = texture(Source, tc+2.0*dx+2.0*dy).xyz;



      color = mul(weights[0], mat4x3(c00, c10, c20, c30));
      color+= mul(weights[1], mat4x3(c01, c11, c21, c31));
      color+= mul(weights[2], mat4x3(c02, c12, c22, c32));
      color+= mul(weights[3], mat4x3(c03, c13, c23, c33));
      color = color/(dot(mul(weights, vec4(1.)), vec4(1.)));



      // Anti-ringing
      //  Get min/max samples
      pc = vTexCoord;
      c00 = texture(Source, pc              ).xyz;
      c11 = texture(Source, pc    +dx       ).xyz;
      c21 = texture(Source, pc    -dx       ).xyz;
      c12 = texture(Source, pc           +dy).xyz;
      c22 = texture(Source, pc           -dy).xyz;


      vec3 min_sample = min4(c11, c21, c12, c22);
      vec3 max_sample = max4(c11, c21, c12, c22);
	min_sample = min(min_sample, c00);
	max_sample = max(max_sample, c00);

      vec3 aux = color;

        color = clamp(color, min_sample, max_sample);
        color = mix(aux, color, params.JINC2_AR_STRENGTH);

   FragColor = vec4(color, 1.);
}
