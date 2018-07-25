// a not-cheap but not-expensive water shader
// decent quality DX9 2012-era water, by Robert Yang (@radiatoryang)

// based on:
// built-in legacy Alpha-Bumped shader
// added cubemap reflection and rimlight stuff
// GlassStainedBumpDistort from Unity glass refraction demo
// http://forum.unity3d.com/threads/grabtexture-uv-correction-in-surface-shader.67742/
// ... this does NOT have fogging or edge blending (too expensive / annoying?)

Shader "Radiator/DX9 Water" {
Properties {
    _Color ("Main Color", Color) = (1,1,1,1)
    // _MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}   // I don't usually use _MainTex here, but you might want it for a SM2.0 fallback
    _BumpMap ("Normalmap", 2D) = "bump" {}
    _RimColor ("Rim Color", Color) = (0.26,0.19,0.16,0.0)
    _RimPower ("Rim Power", Range(0.5,8.0)) = 3.0
    _ReflectColor ("Reflection Color", Color) = (1,1,1,0.5)
    _Cube ("Reflection Cubemap", Cube) = "_Skybox" {}
    _DistortAmt  ("Distortion", range (0,128)) = 10
}

SubShader {

        // grab screen pass
        GrabPass {
            Name "BASE"
            Tags { "LightMode" = "Always" }
        }
        
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Opaque"}
        LOD 300
            
        CGPROGRAM
        #pragma surface surf Lambert alpha:blend vertex:vert
        #include "UnityCG.cginc"

        // sampler2D _MainTex;
        sampler2D _BumpMap;
        fixed4 _Color;
        
        // reflection, rimlight
        samplerCUBE _Cube;
        fixed4 _ReflectColor;
        fixed4 _RimColor;
        fixed _RimPower;
        
        // refraction
        sampler2D _GrabTexture;
        float4 _GrabTexture_TexelSize;
        fixed _DistortAmt;

        struct Input {
            float2 uv_MainTex;
            float2 uv_BumpMap;
            float3 worldRefl; // for cubemap
            float3 viewDir; // for fresnel
            float4 screenPos; // for refraction
            INTERNAL_DATA
        };

        // very basic water sine wave vertex animation
        void vert (inout appdata_full v) {
            // in my game, I use timeScale = 0.5 for reasons; you'll want to slow this down probably
            v.vertex.y += sin(_Time.z * 4 + v.vertex.x + v.vertex.z) * 0.03;
         }

        void surf (Input IN, inout SurfaceOutput o) {
            // I actually leave the _MainTex blank usually, so that's why it's commented out
            // fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
            // o.Albedo = c.rgb;
            o.Albedo = _Color.rgb;
            
            // I use 3 layers of bumps b/c it's too obvious that it's jus scrolling layers when it's just 2
            // in my game, I use timeScale = 0.5 for reasons; you'll want to slow this down probably
            o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap + fixed2(_Time.x * 0.62, _Time.x * 1.1) ));
            o.Normal += UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap * 1.6 + fixed2(_Time.x * -1.3, _Time.x * -1.17) ));
            o.Normal += UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap * 0.8 - fixed2(_Time.x * 0.85, _Time.x * -1.17) ));
            
            // refraction stuff
            fixed2 distort = o.Normal * _DistortAmt * _GrabTexture_TexelSize.xy;
            IN.screenPos.xy += distort * IN.screenPos.z;
            // for openGL and SM2 cards, grabpass UVs get handled differently? see http://docs.unity3d.com/Manual/SL-BuiltinMacros.html
            #if UNITY_UV_STARTS_AT_TOP
                fixed2 sm2Adjust = IN.screenPos.xy / IN.screenPos.w;
                sm2Adjust.y = 1 - sm2Adjust.y; 
            #endif
            fixed3 refractColor = tex2Dproj( _GrabTexture, IN.screenPos);
            // apply refraction
            o.Albedo += refractColor;
            
            // rimlight
            half rim = 1.0 - saturate(dot (normalize(IN.viewDir), o.Normal));
            // cubemap
            float3 worldRefl = WorldReflectionVector (IN, o.Normal);
            fixed4 reflcol = texCUBE (_Cube, worldRefl);
            // apply rimlight and cubemap
            o.Emission = reflcol.rgb * _ReflectColor.rgb * _ReflectColor.a + _RimColor.rgb * pow (rim, _RimPower);
            
            // opaque, because refraction is already grabbing the "transparency" for us
            o.Alpha = 1;
        }
        ENDCG
    }


FallBack "Legacy Shaders/Transparent/Diffuse"
}