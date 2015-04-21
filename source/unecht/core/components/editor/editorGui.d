﻿module unecht.core.components.editor.editorGui;

version(UEIncludeEditor):

import unecht;

import unecht.core.component;
import unecht.core.components._editor;
import unecht.core.components.sceneNode;

import derelict.imgui.imgui;

///
final class UEEditorGUI : UEComponent 
{
    mixin(UERegisterComponent!());
    
    void render() {
        
        {
            ig_SetNextWindowPos(ImVec2(0,ue.application.mainWindow.size.height-25),ImGuiSetCond_Always);
            
            ig_PushStyleColor(ImGuiCol_WindowBg, ImVec4(1,1,1,0));
            ig_Begin("editor",null,
                ImGuiWindowFlags_AlwaysAutoResize|
                ImGuiWindowFlags_NoTitleBar|
                ImGuiWindowFlags_NoMove);
            
            scope(exit) 
            { 
                ig_End();
                ig_PopStyleColor();
            }
            
            UEGui.Text(format("EditorMode (%s with F1) [%0.1f fps]",EditorRootComponent.visible?"hide":"show",ig_GetIO().Framerate));
        }
        
        if(EditorRootComponent.visible)
        {
            renderControlPanel();
            renderScene();
            renderInspector();
        }
    }
    
    private static float sceneWindowWidth;
    ///
    private static void renderScene()
    {
        ig_SetNextWindowPos(ImVec2(0,0), ImGuiSetCond_Always);
        
        ig_Begin("scene",null,ImGuiWindowFlags_NoMove);
        
        static bool menuOpen=false;
        if(UEGui.Button("menu"))
            menuOpen = true;
        
        if(menuOpen)
        {
            ig_BeginPopup(&menuOpen);
            UEGui.Text("menu");
            ig_Separator();
            
            if(UEGui.Button("add entity"))
            {
                addEmptyEntity();
                menuOpen = false;
            }

            if(UEGui.Button("save Entity"))
            {
                //addEmptyEntity();
                menuOpen = false;
            }
            ig_EndPopup();
        }
        
        ig_Separator();
        
        foreach(n; ue.scene.root.children)
        {
            renderSceneNode(n);
        }
        
        sceneWindowWidth = ig_GetWindowWidth();
        ig_End();
    }

	///
    private static void addEmptyEntity()
    {
        UEEntity.create("new entity",EditorRootComponent.currentEntity?EditorRootComponent.currentEntity.sceneNode:null);
    }

    ///
    private static void renderSceneNode(UESceneNode _node)
    {
        if(_node.entity.hideInEditor)
            return;
        
        const canExpand = _node.children.length>0;
        
        if(canExpand)
        {
            const expanded = UEGui.TreeNode(cast(void*)(_node.entity), _node.entity.name);
            
            if(ig_IsItemActive())
            {
                if(EditorRootComponent.currentEntity !is _node.entity)
                    EditorRootComponent.selectEntity(_node.entity);
            }
			if(ig_IsItemHovered() && ig_IsMouseDoubleClicked(0))
					EditorRootComponent.lookAtNode(_node);
            
            if(!expanded)
                return;
            
            foreach(n; _node.children)
            {
                renderSceneNode(n);
            }
            
            ig_TreePop();
        }
        else
        {
            ig_Bullet();
            ig_PushIdPtr(cast(void*)(_node.entity));
            auto isSelected = EditorRootComponent.currentEntity is _node.entity;
            if(UEGui.Selectable(_node.entity.name,isSelected))
            {
                if(isSelected)
                    EditorRootComponent.selectEntity(null);
                else
                    EditorRootComponent.selectEntity(_node.entity);
            }

			if(ig_IsItemHovered() && ig_IsMouseDoubleClicked(0))
				EditorRootComponent.lookAtNode(_node);
        }
    }

    ///
    private static void renderInspector()
    {
        if(!EditorRootComponent.currentEntity)
            return;

        ig_SetNextWindowPos(ImVec2(sceneWindowWidth+1,0),ImGuiSetCond_Always);
        bool closed;
        ig_Begin("inspector",&closed,
            ImGuiWindowFlags_AlwaysAutoResize|
            ImGuiWindowFlags_NoCollapse|
            ImGuiWindowFlags_NoMove|
            ImGuiWindowFlags_NoResize);
        
        scope(exit)ig_End();
        
        if(closed)
        {
            EditorRootComponent.selectEntity(null);
            return;
        }
        
        string name = EditorRootComponent.currentEntity.name;
        UEGui.InputText("name",name);
        EditorRootComponent.currentEntity.name = name;
        
        foreach(int i, c; EditorRootComponent.currentEntity.components)
        {                
            const isSceneNode = i == 0;
            renderInspectorComponent(c,isSceneNode);
        }
        
        renderInspectorFooter();

		if(component2Remove)
		{
			component2Remove.entity.removeComponent(component2Remove);
			component2Remove = null;
		}
        if(componentToAdd.length>0)
        {
            EditorRootComponent.currentEntity.addComponent(componentToAdd);
            componentToAdd.length = 0;
        }
    }

    ///
    private static void renderInspectorComponent(UEComponent c, bool isSceneNode)
    {
        auto openNode = false;
        if(!isSceneNode)
        {
            ig_PushIdPtr(cast(void*)c);
            openNode = UEGui.TreeNode(c.name);
        }
        else
        {
            UEGui.Text("UESceneNode");
        }
        if(openNode || isSceneNode)
        {
            if(!openNode)
                ig_Indent();
            
            renderInspectorSameline(c);
            
            import unecht.core.componentManager;
            if(auto renderer = c.name in UEComponentsManager.editors)
            {
                renderer.render(c);
            }
            
            if(openNode)
                ig_TreePop();
            else
                ig_Unindent();
        }
        else
        {
            renderInspectorSameline(c);
        }
        
        if(isSceneNode)
            ig_Separator();
    }
    
	static UEComponent componentEdit;
    private static void renderInspectorSameline(UEComponent c)
    {
        auto subtext = " ";
        if(c.enabled)
            subtext = "X";

        ImVec2 size;
        ig_GetWindowContentRegionMax(&size);
        const wndWidth = cast(int)size.x;

        ig_SameLine(wndWidth-32);
        if(UEGui.SmallButton("#"))
			componentEdit = c;

		if(componentEdit == c)
			renderComponentEdit();

        ig_SameLine(wndWidth-15);
        if(UEGui.SmallButton(subtext))
            c.enabled = !c.enabled;
    }

	static UEComponent component2Remove;

	private static void renderComponentEdit()
	{
		bool menuOpen=true;
		ig_BeginPopup(&menuOpen);
		scope(exit)ig_EndPopup();

		if(!menuOpen)
		{
			componentEdit = null;
			return;
		}

		UEGui.Text("edit");
		ig_Separator();

		if(UEGui.Button("remove"))
		{
			component2Remove = componentEdit;
			componentEdit = null;
		}
	}

    static bool addComponentOpen;
    static string componentToAdd;

    private static void renderInspectorFooter()
    {
        ig_Separator();
        if(UEGui.Button("add  component..."))
            addComponentOpen = true;

        if(addComponentOpen)
        {
            static string filterString;

            bool menuOpen=true;
            ig_BeginPopup(&menuOpen);
            scope(exit)ig_EndPopup();
            if(!menuOpen)
            {
                addComponentOpen=false;
                filterString.length=0;
            }

            UEGui.InputText("filter",filterString);
            ig_Separator();

            import unecht.core.componentManager;
            foreach(c; UEComponentsManager.componentNames)
            {
                import std.string;
                if(c.indexOf(filterString,CaseSensitive.no)==-1)
                    continue;

                if(UEGui.Selectable(c,false))
                {
                    componentToAdd = c;
                    addComponentOpen=false;
                    filterString.length=0;
                }
            }
        }
    }
    
    ///
    private static void renderControlPanel()
    {
        static float w=100;
        ig_SetNextWindowPos(ImVec2(ue.application.mainWindow.size.width-w,0),ImGuiSetCond_Always);
        
        ig_Begin("controls",null,
            ImGuiWindowFlags_NoTitleBar|
            ImGuiWindowFlags_AlwaysAutoResize|
            ImGuiWindowFlags_NoResize|
            ImGuiWindowFlags_NoMove);
        
        if(ig_Button("play"))
            ue.scene.playing = true;
        
        if(ue.scene.playing)
        {
            if(ig_Button("stop"))
                ue.scene.playing = false;
        }
        else
        {
            if(ig_Button("step"))
                ue.scene.step;
        }
        
        w = ig_GetWindowWidth();
        ig_End();
    }
}