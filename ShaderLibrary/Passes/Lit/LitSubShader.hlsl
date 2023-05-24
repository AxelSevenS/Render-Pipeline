#ifndef LIT_SUBSHADER_INCLUDED
#define LIT_SUBSHADER_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Passes/Lit/LitInput.hlsl"



#ifndef CustomVertexDisplacement
    // Default vertex displacement for Lit shader

    void DefaultVertexDisplacement( inout VertexOutput output ) {
        
    }

    #define CustomVertexDisplacement(output) DefaultVertexDisplacement(output)
#endif

#ifndef CustomClipping
    bool DefaultClipping( in VertexOutput input, half facing ) {
        return false;
    }

    #define CustomClipping(input, facing) DefaultClipping(input, facing)
#endif

#ifndef CustomFragment
    // Default fragment shader for Lit shader 

    void DefaultFragment( inout SurfaceData surfaceData, inout InputData inputData, VertexOutput input, half facing ) {

        surfaceData.albedo = float3(10, 0, 10);
        surfaceData.alpha = 1;
        surfaceData.specular = 0;
        surfaceData.metallic = 0;
        surfaceData.smoothness = 0;
        surfaceData.emission = half3(1, 0, 1);

    }

    #define CustomFragment(surfaceData, inputData, input, facing) DefaultFragment(surfaceData, inputData, input, facing)
#endif


void InitializeVertexOutput( inout VertexOutput output, VertexInput input ) {

    input.normalOS = normalize(input.normalOS);

    // GPU Instancing support
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
    output.normalWS = TransformObjectToWorldNormal(input.normalOS.xyz);

#if (SHADERPASS == SHADERPASS_FORWARD) || (SHADERPASS == SHADERPASS_GBUFFER)
    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
    #if defined(DYNAMICLIGHTMAP_ON)
        output.dynamicLightmapUV.xy = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif
    // OUTPUT_SH(normalWS, output.vertexSH);
#endif

    output.uv = input.uv;


    CustomVertexDisplacement( output );


    output.positionCS = TransformWorldToHClip( output.positionWS );
    #ifdef SHADERGRAPH_PREVIEW
        output.positionSS = float4(0,0,0,0);
    #else
        output.positionSS = ComputeScreenPos( output.positionCS );
    #endif
    
    output.tangentWS = TransformObjectToWorldNormal(input.tangentOS.xyz);
    output.bitangentWS = input.tangentOS.w * cross(output.normalWS.xyz, output.tangentWS.xyz);

    output.viewDirectionWS = GetWorldSpaceNormalizeViewDir(output.positionWS);

    
}

void InitiliazeEmptySurfaceData( inout SurfaceData surfaceData ) {
    surfaceData.normalTS = float3(0, 1, 0);
    surfaceData.occlusion = 1;
    surfaceData.clearCoatMask = 0;
    surfaceData.clearCoatSmoothness = 0;
    surfaceData.albedo = 1.0.xxx;
    surfaceData.alpha = 1;
    surfaceData.specular = 1.0.xxx;
    surfaceData.metallic = 0;
    surfaceData.smoothness = 0.5;
    surfaceData.emission = 0.0.xxx;
}

void InitializeLightingData( inout SurfaceData surfaceData, inout InputData inputData, VertexOutput input ) {

    InitiliazeEmptySurfaceData( surfaceData );

    inputData.positionWS = input.positionWS;
    inputData.positionCS = input.positionCS;
    inputData.normalWS = input.normalWS;
    inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(inputData.positionWS);

    // Shadow coord
#ifdef SHADERGRAPH_PREVIEW
    inputData.shadowCoord = float4(0,0,0,0);
#else
    #if SHADOWS_SCREEN
        inputData.shadowCoord = input.positionSS;
    #else 
        inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    #endif
#endif
    inputData.vertexLighting = 0.0.xxx;
    

    // Lightmap UV / Vertex SH
#if defined(DEBUG_DISPLAY)
    #if defined(DYNAMICLIGHTMAP_ON)
        inputData.dynamicLightmapUV = input.dynamicLightmapUV;
    #endif
    #if defined(LIGHTMAP_ON)
        inputData.staticLightmapUV = input.staticLightmapUV;
    #else
        inputData.vertexSH = input.vertexSH;
    #endif
#endif

    // Global Illumination / Spherical Harmonics
    half3 vertexSH = SampleSHVertex(inputData.normalWS);
#if defined(DYNAMICLIGHTMAP_ON)
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV.xy, vertexSH, inputData.normalWS);
#else
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, vertexSH, inputData.normalWS);
#endif
    inputData.normalizedScreenSpaceUV = input.positionSS;
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);

    // Tangent to World space conversion matrix
    inputData.tangentToWorld = half3x3(
        input.bitangentWS.x, input.tangentWS.x, input.normalWS.x, 
        input.bitangentWS.y, input.tangentWS.y, input.normalWS.y, 
        input.bitangentWS.z, input.tangentWS.z, input.normalWS.z
    );
    
}


#endif