using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class CameraConfig : MonoBehaviour {

	void Start () {
		Camera camera = GetComponent<Camera>();
		camera.depthTextureMode = DepthTextureMode.Depth;
	}
	
	void Update () {
		//Camera camera = GetComponent<Camera>();
		//camera.depthTextureMode = DepthTextureMode.Depth;
	}
}
//For the camera in editor
// Camera.main.depthTextureMode = DepthTextureMode.Depth;
