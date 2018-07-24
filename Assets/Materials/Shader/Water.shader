Shader "Effects/Water" {
  Properties {
    _Color ("Main Color", Color) = (1,1,1,1)
    _DeepColor ("Deep Color", Color) = (0,0,0,0)
    _DeepPower("Deep Power", Range (0, 10)) = 1
    _DeeperColor("Deeper Color", Color) = (0,0,0,0)
    _DeeperPower("Deeper Power", Range(0, 10)) = 1
    _DeepestColor ("Deepest Color", Color) = (0,0,0,0)
    _DeepestPower("Deepeset Power", Range (0, 10)) = 1
    _DeepDistortionPower("Water Distortion Power", Range (0, 0.1)) = 0
    _SpecColor ("Specular Color", Color) = (0.5, 0.5, 0.5, 1)
    _Shininess ("Shininess", Range (0.03, 1)) = 0.078125
    _Glossiness ("Glossiness", Range (0, 1)) = 0.5
    _BumpMap ("Normalmap", 2D) = "bump" {}
    _BumpScale("Normal Power", Range (0, 1)) = 0
    _WaterDistortionPower("Water Distortion Power", Range (0, 1)) = 0
    [MaterialToggle] _ReflSky("Reflect Sky", Float) = 0
    _ReflectionScale("Reflection Power", Range (0, 1)) = 0.2
    [MaterialToggle] _AnimateVertex ("Animate Vertex?", Float) = 0
  }

  CGINCLUDE
  fixed4 _Color;
  fixed4 _DeepColor;
  fixed4 _DeeperColor;
  fixed4 _DeepestColor;
  fixed4 _FoamPower;
  half _DeepPower;
  half _DeeperPower;
  half _DeepestPower;
  half _DeepDistortionPower;
  half _Glossiness;
  sampler2D _BumpMap;
  float4 _BumpMap_ST;
  half _AnimateVertex;
  half _Shininess;
  half _BumpScale;
  half _WaterDistortionPower;

  half _ReflectionScale;

  sampler2D _CameraDepthTexture;
 
  struct Input {
    float2 tc_BumpMap;
    float4 ref;
    float4 vertex;
    float3 viewDir;
    float3 worldRefl;
    INTERNAL_DATA
  };

  void vert (inout appdata_full v, out Input o) {
    UNITY_INITIALIZE_OUTPUT(Input, o);

    o.tc_BumpMap = TRANSFORM_TEX(v.texcoord1, _BumpMap);

    if(_AnimateVertex){
      float time = _Time.x * 0.4;
      float4 wave = tex2Dlod(_BumpMap, float4(o.tc_BumpMap + time, 0, 0));
      v.vertex.y += sin(wave.g * 0.3 * _WaterDistortionPower) ;
    }

    o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
    o.vertex = UnityObjectToClipPos(v.vertex);
    o.ref = ComputeScreenPos(o.vertex);
    COMPUTE_EYEDEPTH(o.ref.w);
  }

  void surf (Input IN, inout SurfaceOutput o) {

    float time = _Time.x * 0.4;
    fixed4 normalMap = tex2D(_BumpMap, IN.tc_BumpMap - time);
    fixed4 normalMap2 = tex2D(_BumpMap, IN.tc_BumpMap + time);
    fixed4 bump = (normalMap + normalMap2) * 0.5;

    float depthSample = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, IN.ref + (sin(bump.b * _Time.x * 0.02) * _DeepDistortionPower));
    float depth = LinearEyeDepth (depthSample);

    float deepFactor = (1 - saturate(_DeepPower * (depth - IN.ref.w)));
    float deeperFactor = (1 - saturate(_DeeperPower * (depth - IN.ref.w)));
    float deepestFactor = (1 - saturate(_DeepestPower * (depth - IN.ref.w)));

    half3 color = lerp(_DeepColor, _Color, deepFactor);
    color = lerp(_DeeperColor, color, deeperFactor);
    color = lerp(_DeepestColor, color, deepestFactor);

    float3 reflectedDir = -IN.worldRefl;
    half4 skyData = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, reflectedDir + (bump.b * 0.1));
    
    o.Albedo = color + (skyData * _ReflectionScale);
    o.Emission = 0;
    o.Gloss = _Glossiness;
    o.Alpha = _Color.a;
    o.Specular = _Shininess;
    o.Normal = UnpackScaleNormal(bump, _BumpScale);
  }
  ENDCG

  SubShader {
    Tags{ "Queue" = "Transparent" "RenderType" = "Transparent" }
    LOD 100

    CGPROGRAM
    #pragma surface surf BlinnPhong vertex:vert fullforwardshadows alpha:fade nolightmap
    #pragma target 3.0

    ENDCG
  }
  FallBack "Legacy Shaders/Specular"
}
