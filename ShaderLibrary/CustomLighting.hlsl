#ifndef CEL_LIGHTING_INCLUDED
#define CEL_LIGHTING_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"

#define _AmbientLight _MainLightColor.rgb*0.35


float3 ColorSaturation(float3 color, float saturation) {
    if (saturation == 0)
        return color;
        
    // if (RGBtoSaturation(color) == 0)
    //     return color;

    float3 hsv = RgbToHsv(color);

    // hsv.y += saturation;
    // float3 saturatedColor = saturate(HSVtoRGB(hsv));

    float3 saturatedColor = HsvToRgb(float3(hsv.r, saturation, hsv.b));

    return saturate(saturatedColor);
}

half PhongReflection( half3 normal, half3 viewDir, half3 lightDir, half smoothness ) {
    half3 V = normalize( -viewDir );
    half3 R = reflect( normalize( lightDir ), normalize( normal ) );
    return pow( saturate( dot( V, R ) ), smoothness );
}

half GetAccent(half luminance) {
    // P-Curve

    half h = 5 * luminance + 1;
    return h * exp(1-h);
}

half GetSpecular(half3 worldNormal, half3 worldViewDirection, half3 lightDirectionWS, half smoothness, half shade) {
    half phong = PhongReflection(worldNormal, worldViewDirection, lightDirectionWS, smoothness*100);
    return smoothstep(0.15, 1.0, phong * shade);
}

half GetRadiance(half3 worldNormal, half3 lightDirectionWS) {
    return saturate( dot(worldNormal, lightDirectionWS) );
}

half GetShade(half radiance, half attenuation) {
    const half shadeUpperLimit = 0.15;
    const half lightLowerLimit = 0.55;

    return smoothstep(shadeUpperLimit, lightLowerLimit, radiance) * smoothstep(0, lightLowerLimit - shadeUpperLimit, attenuation);
}



// --------------------------------------------------------------------------------------
// This is the function that is called by both Deferred and Forward rendering paths
// It is called once per light
// It uses InputData and SurfaceData to get the data it needs to calculate the lighting
// To customize the lighting, simply modify the code below

// InputData contains :
// inputData.positionWS : world space position of the fragment
// inputData.positionCS : clip space position of the fragment
// inputData.normalWS : world space normal of the fragment
// inputData.viewDirectionWS : world space view direction of the fragment
// inputData.fogCoord : fog coord of the fragment
// inputData.vertexLighting : vertex lighting of the fragment
// inputData.normalizedScreenSpaceUV : normalized screen space UV of the fragment
// inputData.shadowMask : shadow mask of the fragment
// inputData.tangentToWorld : tangent to world matrix of the fragment

// SurfaceData contains :
// surfaceData.albedo : albedo of the fragment
// surfaceData.specular : specular color of the fragment
// surfaceData.metallic : metallic of the fragment
// surfaceData.smoothness : smoothness of the fragment
// surfaceData.normalTS : tangent space normal of the fragment
// surfaceData.emission : emission color of the fragment
// surfaceData.occlusion : occlusion of the fragment
// surfaceData.alpha : alpha of the fragment
half3 CustomLighting( InputData inputData, SurfaceData surfaceData, Light light ) {
    light.direction = normalize(light.direction);
    
    half radiance = GetRadiance(inputData.normalWS, light.direction);
    half shade = GetShade(radiance, light.distanceAttenuation * light.shadowAttenuation);

    half3 litColor = (light.color * 0.3/*  * _AmbientLight */);
    
    half accentIntensity = 1 - surfaceData.smoothness;
    if (accentIntensity > 0) {

        half accent = GetAccent(shade);
        litColor = lerp(litColor, ColorSaturation(litColor, accentIntensity), accent);
    }

    half3 finalColor = shade * surfaceData.albedo * litColor;

    half specularIntensity = surfaceData.specular.r;
    if (specularIntensity > 0 && surfaceData.smoothness > 0) {

        half specular = GetSpecular(inputData.normalWS, inputData.viewDirectionWS, light.direction, surfaceData.smoothness, shade);
        finalColor += litColor * surfaceData.specular * specular;
    }

    return finalColor;

}


#endif