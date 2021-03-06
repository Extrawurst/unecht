﻿module unecht.core.components.camera;

import unecht.core.components.misc;
import unecht.core.components.renderer;
import unecht.core.component;
import unecht.core.object;
import unecht.core.componentManager;
import unecht.core.entity;

import unecht.core.types;
import unecht.core.math.ray;

import gl3n.linalg;

//TODO: create mixin and automation
version(UEIncludeEditor)
@EditorInspector("UECamera")
static class UECameraInspector : IComponentEditor
{
	/// render custom inspector for UECamera
	override bool render(UEObject _component)
	{
		auto thisT = cast(UECamera)_component;

		import derelict.imgui.imgui;
		import unecht.core.components.internal.gui;
		import std.format;

		igColorEdit4("clearColor",thisT.clearColor.vector,true);
		UEGui.DragFloat("fov",thisT.fieldOfView,1,360);
		UEGui.DragFloat("near",thisT.clipNear,0.01f);
		UEGui.DragFloat("far",thisT.clipFar,0.01f);

		igCheckbox("isOrthographic",&thisT.isOrthographic);
		if(thisT.isOrthographic)
		{
			UEGui.DragFloat("orthoSize",thisT.orthoSize,0.01f);
		}

		//TODO: impl
		return false;
	}

	mixin UERegisterInspector!UECameraInspector;
}

//TODO: add properties and make matrix updates implicit
/// camera component - handles rendering the world through its perspective
final class UECamera : UEComponent
{
	mixin(UERegisterObject!());

	/// return projection matrix multiplied by look matrix
	@property auto projectionLook() const { return matProjection * matLook; }

	@Serialize{
		float fieldOfView = 60;
		float clipNear = 1;
		float clipFar = 1000;

		vec4 clearColor = vec4(0,0,0,1);
		bool clearBitColor = true;
		bool clearBitDepth = true;
		int visibleLayers = UECameraDefaultLayers;

		bool isOrthographic=false;
		float orthoSize=1;

		UERect viewport;
	}

	///
	public ray screenToRay(vec2 screenPos)
	{
		import unecht.ue:ue;

		UESize viewportSize = UESize(
			cast(int)(viewport.size.x * ue.application.windowSize.width),
			cast(int)(viewport.size.y * ue.application.windowSize.height));

		float x = (2.0f * screenPos.x) / viewportSize.width - 1.0f;
		float y = (2.0f * screenPos.y) / viewportSize.height - 1.0f;

		auto mouseClip = vec4 (x, -y, 1, 1);

		auto matUnproj = matProjection.inverse();

		auto mouseWorld = matUnproj * mouseClip;

		mouseWorld /= (mouseWorld.w);

		auto dir = mouseWorld.xyz;

		dir.normalize();

		dir = dir.xyz * matLook.get_rotation();

		return ray(entity.sceneNode.position, dir);
	}

	///
	private void updateLook()
	{
		auto lookat = entity.sceneNode.position + entity.sceneNode.forward;

		matLook = mat4.look_at(entity.sceneNode.position, lookat, entity.sceneNode.up);
	}

	///
	private void updateProjection()
	{
		if(!isOrthographic)
		{
			import unecht.ue:ue;
			auto w = ue.application.framebufferSize.width;
			auto h = ue.application.framebufferSize.height;
			matProjection = mat4.perspective(w, h, fieldOfView, clipNear, clipFar);
		}
		else
		{
			matProjection = mat4.orthographic(-(orthoSize/2),(orthoSize/2),-(orthoSize/2),(orthoSize/2),clipNear,clipFar);
		}
	}

	/// render all renderables through the perspective of this camera
	///TODO: note: needs to be moved aways
	public void render()
	{
		import unecht.ue:ue;
		import derelict.opengl3.gl3;

		updateProjection();
		updateLook();

		int clearBits = 0;
		if(clearBitColor) clearBits |= GL_COLOR_BUFFER_BIT;
		if(clearBitDepth) clearBits |= GL_DEPTH_BUFFER_BIT;

		if(clearBits!=0)
		{
			glClearColor(clearColor.r, clearColor.g, clearColor.b, clearColor.a);
			glClear(clearBits);
		}

		UESize viewportSize = UESize(
			cast(int)(viewport.size.x * ue.application.framebufferSize.width),
			cast(int)(viewport.size.y * ue.application.framebufferSize.height));
		glViewport(viewport.pos.left,viewport.pos.top,viewportSize.width,viewportSize.height);

		auto renderers = ue.scene.gatherAllComponents!UERenderer;

		foreach(r; renderers)
		{
			if(r.enabled && r.sceneNode.enabled)
			{
				import unecht.core.stdex;
				if(testBit(visibleLayers, r.entity.layer))
					r.render(this);
			}
		}
	}

private:
	mat4 matProjection = mat4.identity;
	mat4 matLook = mat4.identity;
}
