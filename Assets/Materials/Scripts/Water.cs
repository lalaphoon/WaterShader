using System.Collections;
using System.Collections.Generic;
using EOTR;
using UnityEngine;

namespace EOTR.Effects {
  [ExecuteInEditMode]
  public class Water : MonoBehaviour {

    public enum WaterMode {
      Simple = 0,
      Reflective = 1,
      Refractive = 2,
    }

    public WaterMode waterMode = WaterMode.Refractive;
    public int renderTextureSize = 256;
    public float clipPlaneOffset = 0.07f;
    public LayerMask m_ReflectLayers = -1;

    private Camera reflectionCamera = null;
    private Camera refractionCamera = null;
    private Material waterMaterial = null;
    private RenderTexture reflectionTexture;
    private RenderTexture refractionTexture;

    void Start() {
      UpdateWaterEffectElements();
    }

    void OnDestroy() {
      if (reflectionCamera != null)
        DestroyImmediate(reflectionCamera.gameObject);

      if (refractionCamera != null)
        DestroyImmediate(refractionCamera.gameObject);
    }

    public void UpdateWaterEffectElements() {
      if (waterMaterial == null)
        SetWaterMaterial();

      if (reflectionCamera == null)
        reflectionCamera = CreateEffectCamera("_Reflection_Camera");

      if (refractionCamera == null)
        refractionCamera = CreateEffectCamera("_Refraction_Camera");
    }

    void SetWaterMaterial() {
      Renderer rend = GetComponent<Renderer>();
      if (rend == null && rend.sharedMaterial == null)
        return;

      waterMaterial = rend.sharedMaterial;
    }

    Camera CreateEffectCamera(string name) {
      Camera cam = null;
      GameObject go = GameObject.Find(name + "_" + GetInstanceID());
      if (go == null) {
        go = new GameObject(name + "_" + GetInstanceID(), typeof(Camera), typeof(Skybox));
        go.hideFlags = HideFlags.HideAndDontSave;
      }
      cam = go.GetComponent<Camera>();
      cam.enabled = false;
      cam.useOcclusionCulling = false;
      cam.allowMSAA = false;
      cam.allowHDR = false;
      cam.targetTexture = new RenderTexture(renderTextureSize, renderTextureSize, 16);
      cam.targetTexture.isPowerOfTwo = true;
      //cam.gameObject.AddComponent<FlareLayer>();

      return cam;
    }

    public void OnWillRenderObject() {
      UpdateWaterEffectElements();

      Camera currentCamera = Camera.current;
      if (currentCamera == null)
        return;

      UpdateCameraModes(currentCamera, reflectionCamera);
      UpdateCameraModes(currentCamera, refractionCamera);

      Vector3 position = gameObject.transform.position;
      Vector3 normal = gameObject.transform.up;

      reflectionTexture = null;
      refractionTexture = null;

      if (waterMode >= WaterMode.Reflective && reflectionCamera != null) {
        float dis = -Vector3.Dot(normal, position) - clipPlaneOffset;
        Vector4 reflectionPlane = new Vector4(normal.x, normal.y, normal.z, dis);

        Matrix4x4 reflection = Matrix4x4.zero;
        CalculateReflectionMatrix(ref reflection, reflectionPlane);
        reflectionCamera.worldToCameraMatrix = currentCamera.worldToCameraMatrix * reflection;

        Vector4 clipPlane = CameraSpacePlane(reflectionCamera, position, normal, 1f);
        reflectionCamera.projectionMatrix = currentCamera.CalculateObliqueMatrix(clipPlane);
        reflectionCamera.cullingMask = ~(1 << 4) & m_ReflectLayers.value;
        reflectionCamera.Render();

        reflectionTexture = reflectionCamera.targetTexture;
      }

      if (waterMode >= WaterMode.Refractive && refractionCamera != null && Application.isPlaying) {

        Vector4 clipPlane = CameraSpacePlane(refractionCamera, position, normal, -1.0f);
        refractionCamera.projectionMatrix = currentCamera.CalculateObliqueMatrix(clipPlane);
        refractionCamera.cullingMatrix = currentCamera.projectionMatrix * currentCamera.worldToCameraMatrix;
        refractionCamera.cullingMask = ~(1 << 4) & m_ReflectLayers.value;
        refractionCamera.transform.position = currentCamera.transform.position;
        refractionCamera.transform.rotation = currentCamera.transform.rotation;
        refractionCamera.Render();

        refractionTexture = refractionCamera.targetTexture;
      }

      SetEffectTextures(reflectionTexture, refractionTexture);
    }

    void OnRenderObject() {
      if (waterMode >= WaterMode.Reflective && reflectionCamera != null)
        reflectionTexture = reflectionCamera.targetTexture;

      if (waterMode >= WaterMode.Refractive && refractionCamera != null)
        refractionTexture = refractionCamera.targetTexture;

      SetEffectTextures(reflectionTexture, refractionTexture);
    }

    void SetEffectTextures(RenderTexture reflectionTexture, RenderTexture refractionTexture) {
      if (waterMaterial != null) {
        if (reflectionTexture != null && waterMaterial.HasProperty("_ReflectionTex"))
          waterMaterial.SetTexture("_ReflectionTex", reflectionTexture);

        if (refractionTexture != null && waterMaterial.HasProperty("_RefractionTex"))
          waterMaterial.SetTexture("_RefractionTex", refractionTexture);
      }
    }

    void UpdateCameraModes(Camera src, Camera dest) {
      if (dest == null)
        return;

      dest.clearFlags = src.clearFlags;
      dest.backgroundColor = src.backgroundColor;
      if (src.clearFlags == CameraClearFlags.Skybox) {
        Skybox sky = src.GetComponent(typeof(Skybox)) as Skybox;
        Skybox mysky = dest.GetComponent(typeof(Skybox)) as Skybox;
        if (!sky || !sky.material) {
          mysky.enabled = false;
        } else {
          mysky.enabled = true;
          mysky.material = sky.material;
        }
      }

      dest.farClipPlane = src.farClipPlane;
      dest.nearClipPlane = src.nearClipPlane;
      dest.orthographic = src.orthographic;
      dest.fieldOfView = src.fieldOfView;
      dest.aspect = src.aspect;
      dest.orthographicSize = src.orthographicSize;
    }

    private Vector4 CameraSpacePlane(Camera cam, Vector3 position, Vector3 normal, float sideSign) {
      Vector3 offsetPos = position + normal * clipPlaneOffset;
      Matrix4x4 m = cam.worldToCameraMatrix;
      Vector3 cposition = m.MultiplyPoint(offsetPos);
      Vector3 cnormal = m.MultiplyVector(normal).normalized * sideSign;
      return new Vector4(cnormal.x, cnormal.y, cnormal.z, -Vector3.Dot(cposition, cnormal));
    }

    private static void CalculateReflectionMatrix(ref Matrix4x4 reflectionMat, Vector4 plane) {
      reflectionMat.m00 = (1F - 2F * plane[0] * plane[0]);
      reflectionMat.m01 = (-2F * plane[0] * plane[1]);
      reflectionMat.m02 = (-2F * plane[0] * plane[2]);
      reflectionMat.m03 = (-2F * plane[3] * plane[0]);

      reflectionMat.m10 = (-2F * plane[1] * plane[0]);
      reflectionMat.m11 = (1F - 2F * plane[1] * plane[1]);
      reflectionMat.m12 = (-2F * plane[1] * plane[2]);
      reflectionMat.m13 = (-2F * plane[3] * plane[1]);

      reflectionMat.m20 = (-2F * plane[2] * plane[0]);
      reflectionMat.m21 = (-2F * plane[2] * plane[1]);
      reflectionMat.m22 = (1F - 2F * plane[2] * plane[2]);
      reflectionMat.m23 = (-2F * plane[3] * plane[2]);

      reflectionMat.m30 = 0F;
      reflectionMat.m31 = 0F;
      reflectionMat.m32 = 0F;
      reflectionMat.m33 = 1F;
    }
  }
}
