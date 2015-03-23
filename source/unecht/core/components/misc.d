﻿module unecht.core.components.misc;

import unecht;
import unecht.core.component;
import unecht.core.components.camera;

import unecht.gl.vertexBufferObject;
import unecht.gl.shader;
import derelict.opengl3.gl3;

/// 
final class UEMesh : UEComponent
{
	mixin(UERegisterComponent!());

	GLVertexBufferObject vertexBuffer;
}

/// 
final class UEMaterial : UEComponent
{
	mixin(UERegisterComponent!());

	//TODO: remove shader hardwiring
	static const string simpleVShader = cast(string)import("simplevs.glsl");
	static const string simpleFShader = cast(string)import("simplefs.glsl");

	GLProgram program;

	bool polygonFill = true;

	override void onCreate() {
		super.onCreate;

		auto vshader = scoped!GLShader();
		auto fshader = scoped!GLShader();
		scope(exit) vshader.destroy();
		scope(exit) fshader.destroy();

		vshader.create(ShaderType.vertex, simpleVShader);
		fshader.create(ShaderType.fragment, simpleFShader);
		
		program = new GLProgram();
		program.init(vshader,fshader);
	}

	void preRender()
	{
		glPolygonMode( GL_FRONT_AND_BACK, polygonFill ? GL_FILL : GL_LINE );

		program.validate();
		program.bind();
	}

	void postRender()
	{
		program.unbind();

		glPolygonMode( GL_FRONT_AND_BACK, GL_FILL );
	}
}

/// 
final class UERenderer : UEComponent
{
	mixin(UERegisterComponent!());

	UEMaterial material;
	UEMesh mesh;

	void render(UECamera _cam)
	{
		auto mat = _cam.matProjection * _cam.matLook;

		if(material)
			material.preRender();

		import std.string:toStringz;
		auto posLoc = glGetAttribLocation(material.program.program, toStringz("Position"));
		assert(posLoc != -1);
		
		material.program.setUniformMatrix("matWorld", mat);

		mesh.vertexBuffer.bind(posLoc);
		scope(exit) mesh.vertexBuffer.unbind();

		mesh.vertexBuffer.renderIndexed();

		if(material)
			material.postRender();
	}
}