#version 450


layout(push_constant) uniform Push
{
	vec4 OutputSize;
	vec4 OriginalSize;
	vec4 SourceSize;
	uint FrameCount;
    float SAT,BLACK,TEMP,SEGA,BRIGHTNESS,postbr,contrast,
    gamma_out_red,gamma_out_green,gamma_out_blue,
    gamma_in, mono, R,G,B;
} params;

#pragma parameter TEMP "Color Temperature in Kelvins"  9311.0 1031.0 12047.0 72.0
#define TEMP params.TEMP
#pragma parameter SAT "Saturation" 1.0 0.0 2.0 0.01
#define SAT params.SAT
#pragma parameter BRIGHTNESS "Brightness" 1.0 0.0 2.0 0.01
#define BRIGHTNESS params.BRIGHTNESS
#pragma parameter contrast "Contrast" 1.0 0.00 2.00 0.01
#define contrast params.contrast
#pragma parameter BLACK "Black Level" 0.0 -0.20 0.20 0.01 
#define BLACK params.BLACK
#pragma parameter SEGA "SEGA Lum Fix" 0.0 0.0 1.0 1.0
#define SEGA params.SEGA
#pragma parameter postbr "Post Brightness" 1.0 0.0 2.5 0.01
#define postbr params.postbr
#pragma parameter gamma_in "Gamma In" 2.4 1.0 4.0 0.05
#define gamma_in params.gamma_in
#pragma parameter gamma_out_red "Gamma out Red" 2.2 1.0 4.0 0.05
#define gamma_out_red params.gamma_out_red
#pragma parameter gamma_out_green "Gamma out Green" 2.2 1.0 4.0 0.05
#define gamma_out_green params.gamma_out_green
#pragma parameter gamma_out_blue "Gamma out Blue" 2.2 1.0 4.0 0.05
#define gamma_out_blue params.gamma_out_blue
#pragma parameter mono "Mono Display On/Off" 0.0 0.0 1.0 1.0
#define mono params.mono
#pragma parameter R "Mono Red/Channel" 1.0 0.0 2.0 0.01
#define R params.R
#pragma parameter G "Mono Green/Channel" 1.0 0.0 2.0 0.01
#define G params.G
#pragma parameter B "Mono Blue/Channel" 1.0 0.0 2.0 0.01
#define B params.B

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

float saturate(float v) 
    { 
        return clamp(v, 0.0, 1.0);       
    }

vec3 ColorTemp(float temperatureInKelvins)
{
    vec3 retColor;
    temperatureInKelvins = clamp(temperatureInKelvins, 1000.0, 40000.0) / 100.0;
    
    if (temperatureInKelvins <= 66.0)
    {
        retColor.r = 1.0;
        retColor.g = saturate(0.39008157876901960784 * log(temperatureInKelvins) - 0.63184144378862745098);
    }
    else
    {
        float t = temperatureInKelvins - 60.0;
        retColor.r = saturate(1.29293618606274509804 * pow(t, -0.1332047592));
        retColor.g = saturate(1.12989086089529411765 * pow(t, -0.0755148492));
    }
    
    if (temperatureInKelvins >= 66.0)
        retColor.b = 1.0;
    else if(temperatureInKelvins <= 19.0)
        retColor.b = 0.0;
    else
        retColor.b = saturate(0.54320678911019607843 * log(temperatureInKelvins - 10.0) - 1.19625408914);

    return retColor;
}

mat4 contrastMatrix(float contr)
{   
    float t = (1.0 - contr) / 2.0;
    
    return mat4(contr, 0,               0,               0,
                0,               contr, 0,               0,
                0,               0,               contr, 0,
                t,               t,               t,               1);
}


vec3 toGrayscale(vec3 color)
{
  float average = dot(vec3(0.22,0.71,0.07),color);
  return vec3(average);
}

vec3 colorize(vec3 grayscale, vec3 color)
{
    return (grayscale * color);
}



void main()
{
   vec3 col = texture(Source,vTexCoord).rgb;
   col *= BRIGHTNESS;
   col = (contrastMatrix(contrast) * vec4(col,1.0)).rgb;  
//color temperature  
   col *= ColorTemp(TEMP);

//saturation
   float l = dot(col, vec3(0.3,0.6,0.1));
   col = mix(vec3(l), col, SAT); 
   col = pow(col, vec3(gamma_in));
//black level    
   
   if (SEGA == 1.0) col *= 1.0625;
    col *= mix(1.0,postbr,l);
    col = pow(col, vec3(1.0/gamma_out_red,1.0,1.0));
    col = pow(col, vec3(1.0,1.0/gamma_out_green,1.0));
    col = pow(col, vec3(1.0,1.0,1.0/gamma_out_blue));
     col -= vec3(BLACK);
    col*= vec3(1.0)/vec3(1.0-BLACK);
    
    if (mono == 1.0)
    {
    vec3 col1 = toGrayscale (col);
    vec3 c = vec3(R, G, B);
    col = colorize (col1, c);
    }

   FragColor = vec4(col,1.0);
}
