package;

import openfl.display.BitmapData;
#if LUA_ALLOWED
import llua.Lua;
import llua.LuaL;
import llua.State;
import llua.Convert;
#end
import animateatlas.AtlasFrameMaker;
import flixel.FlxG;
import flixel.addons.effects.FlxTrail;
import flixel.input.keyboard.FlxKey;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.text.FlxText;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;
import flixel.util.FlxTimer;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.util.FlxColor;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxSprite;
import openfl.Lib;
import openfl.display.BlendMode;
import openfl.filters.BitmapFilter;
import openfl.utils.Assets;
import flixel.math.FlxMath;
import flixel.util.FlxSave;
import flixel.addons.transition.FlxTransitionableState;
import flixel.system.FlxAssets.FlxShader;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
#if (!flash && sys)
import flixel.addons.display.FlxRuntimeShader;
#end
#if sys
import sys.FileSystem;
import sys.io.File;
#end
import Type.ValueType;
import Controls;
import DialogueBoxPsych;
#if hscript
import hscript.Parser;
import hscript.Interp;
import hscript.Expr;
#end
#if desktop
import Discord;
import Discord.DiscordClient;
#end

#if mobile
#if android
import android.widget.Toast as AndroidToast;
import android.Tools as AndroidTools;
//import android.os.BatteryManager as AndroidBatteryManager;
import android.PsychJNI;
#end

import mobile.TouchUtil;
#end

using StringTools;

class FunkinLua
{
        public static var Function_Stop:Dynamic = 1;
        public static var Function_Continue:Dynamic = 0;
        public static var Function_StopLua:Dynamic = 2;

        // public var errorHandler:String->Void;
        #if LUA_ALLOWED
        public var lua:State = null;
        #end
        public var camTarget:FlxCamera;
        public var scriptName:String = '';
        public var closed:Bool = false;

        #if hscript
        public static var hscript:HScript = null;
        #end

        public static var ir = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('is'));

        #if sys
        static function dbgAppend(path:String, content:String) {
            try {
                var f = sys.io.File.append(path, false);
                f.writeString(content);
                f.close();
            } catch(e:Dynamic) {}
        }
        #end

        public function new(script:String)
        {
                #if LUA_ALLOWED
                var logPath:String = null;
                #if sys
                logPath = Sys.getCwd() + 'lua_debug.log';
                try { sys.io.File.saveContent(logPath, '=== FunkinLua: ' + script + ' ===\n'); } catch(e:Dynamic) { logPath = null; }
                #end

                // Phase 1: Lua state + init
                #if sys if (logPath != null) try { dbgAppend(logPath, 'A: before newstate\n'); } catch(e:Dynamic) {} #end
                try {
                        lua = LuaL.newstate();
                        LuaL.openlibs(lua);
                        #if sys if (logPath != null) try { dbgAppend(logPath, 'B: after newstate+openlibs\n'); } catch(e:Dynamic) {} #end
                        Lua.init_callbacks(lua);
                        #if sys if (logPath != null) try { dbgAppend(logPath, 'C: after init_callbacks\n'); } catch(e:Dynamic) {} #end
                } catch(e:Dynamic) {
                        #if sys if (logPath != null) try { dbgAppend(logPath, 'FAIL P1: ' + Std.string(e) + '\n'); } catch(e:Dynamic) {} #end
                        return;
                }

                // Phase 2: Read file with Haxe + dostring (instead of dofile which uses C fopen)
                #if sys if (logPath != null) try { dbgAppend(logPath, 'D: before File.getContent\n'); } catch(e:Dynamic) {} #end
                var fileContent:String = null;
                try {
                        fileContent = File.getContent(script);
                        #if sys if (logPath != null) try { dbgAppend(logPath, 'E: getContent OK len=' + (fileContent != null ? fileContent.length : 0) + '\n'); } catch(e:Dynamic) {} #end
                } catch(e:Dynamic) {
                        #if sys if (logPath != null) try { dbgAppend(logPath, 'FAIL getContent: ' + Std.string(e) + '\n'); } catch(e:Dynamic) {} #end
                        return;
                }

                if (fileContent == null || fileContent.length < 1) {
                        #if sys if (logPath != null) try { dbgAppend(logPath, 'ERROR: file empty or null\n'); } catch(e:Dynamic) {} #end
                        return;
                }

                #if sys if (logPath != null) try { dbgAppend(logPath, 'F: before dostring\n'); } catch(e:Dynamic) {} #end
                try {
                        var result:Dynamic = LuaL.dostring(lua, fileContent);
                        #if sys if (logPath != null) try { dbgAppend(logPath, 'G: after dostring result=' + result + '\n'); } catch(e:Dynamic) {} #end
                        var resultStr:String = Lua.tostring(lua, result);
                        if (resultStr != null && result != 0) {
                                #if sys if (logPath != null) try { dbgAppend(logPath, 'ERROR dostring: ' + resultStr + '\n'); } catch(e:Dynamic) {} #end
                        }
                        #if sys if (logPath != null) try { dbgAppend(logPath, 'H: dostring OK\n'); } catch(e:Dynamic) {} #end
                } catch(e:Dynamic) {
                        #if sys if (logPath != null) try { dbgAppend(logPath, 'FAIL P2 dostring: ' + Std.string(e) + '\n'); } catch(e:Dynamic) {} #end
                        return;
                }

                scriptName = script;

                // Phase 3: call onCreate
                #if sys if (logPath != null) try { dbgAppend(logPath, 'G: before call onCreate\n'); } catch(e:Dynamic) {} #end
                try {
                        call('onCreate', []);
                        #if sys if (logPath != null) try { dbgAppend(logPath, 'H: after call onCreate\n'); } catch(e:Dynamic) {} #end
                } catch(e:Dynamic) {
                        #if sys if (logPath != null) try { dbgAppend(logPath, 'FAIL P3 onCreate: ' + Std.string(e) + '\n'); } catch(e:Dynamic) {} #end
                }

                #if sys if (logPath != null) try { dbgAppend(logPath, '=== DONE ===\n'); } catch(e:Dynamic) {} #end
                #end
        }

        public static function isOfTypes(value:Any, types:Array<Dynamic>)
        {
                for (type in types)
                {
                        if (Std.isOfType(value, type))
                                return true;
                }
                return false;
        }

        #if hscript
        public function initHaxeModule()
        {
                if (hscript == null)
                {
                        trace('initializing haxe interp for: $scriptName');
                        hscript = new HScript(); // TO DO: Fix issue with 2 scripts not being able to use the same variable names
                }
        }
        #end

        public static function setVarInArray(instance:Dynamic, variable:String, value:Dynamic):Any
        {
                var shit:Array<String> = variable.split('[');
                if (shit.length > 1)
                {
                        var blah:Dynamic = null;
                        if (PlayState.instance.variables.exists(shit[0]))
                        {
                                var retVal:Dynamic = PlayState.instance.variables.get(shit[0]);
                                if (retVal != null)
                                        blah = retVal;
                        }
                        else
                                blah = Reflect.getProperty(instance, shit[0]);

                        for (i in 1...shit.length)
                        {
                                var leNum:Dynamic = shit[i].substr(0, shit[i].length - 1);
                                if (i >= shit.length - 1) // Last array
                                        blah[leNum] = value;
                                else // Anything else
                                        blah = blah[leNum];
                        }
                        return blah;
                }
                /*if(Std.isOfType(instance, Map))
                                instance.set(variable,value);
                        else */

                if (PlayState.instance.variables.exists(variable))
                {
                        PlayState.instance.variables.set(variable, value);
                        return true;
                }

                Reflect.setProperty(instance, variable, value);
                return true;
        }

        public static function getVarInArray(instance:Dynamic, variable:String):Any
        {
                var shit:Array<String> = variable.split('[');
                if (shit.length > 1)
                {
                        var blah:Dynamic = null;
                        if (PlayState.instance.variables.exists(shit[0]))
                        {
                                var retVal:Dynamic = PlayState.instance.variables.get(shit[0]);
                                if (retVal != null)
                                        blah = retVal;
                        }
                        else
                                blah = Reflect.getProperty(instance, shit[0]);

                        for (i in 1...shit.length)
                        {
                                var leNum:Dynamic = shit[i].substr(0, shit[i].length - 1);
                                blah = blah[leNum];
                        }
                        return blah;
                }

                if (PlayState.instance.variables.exists(variable))
                {
                        var retVal:Dynamic = PlayState.instance.variables.get(variable);
                        if (retVal != null)
                                return retVal;
                }

                return Reflect.getProperty(instance, variable);
        }

        inline static function getTextObject(name:String):FlxText
        {
                return PlayState.instance.modchartTexts.exists(name) ? PlayState.instance.modchartTexts.get(name) : Reflect.getProperty(PlayState.instance, name);
        }

        #if (!flash && sys)
        public function getShader(obj:String):FlxRuntimeShader
        {
                var killMe:Array<String> = obj.split('.');
                var leObj:FlxSprite = getObjectDirectly(killMe[0]);
                if (killMe.length > 1)
                {
                        leObj = getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length - 1]);
                }

                if (leObj != null)
                {
                        var shader:Dynamic = leObj.shader;
                        var shader:FlxRuntimeShader = shader;
                        return shader;
                }
                return null;
        }
        #end

        function initLuaShader(name:String, ?glslVersion:Int = 120)
        {
                if (!ClientPrefs.shaders)
                        return false;

                #if (!flash && sys)
                if (PlayState.instance.runtimeShaders.exists(name))
                {
                        luaTrace('Shader $name was already initialized!');
                        return true;
                }

                var foldersToCheck:Array<String> = [Paths.mods('shaders/')];
                if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
                        foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/shaders/'));

                for (mod in Paths.getGlobalMods())
                        foldersToCheck.insert(0, Paths.mods(mod + '/shaders/'));

                for (folder in foldersToCheck)
                {
                        if (FileSystem.exists(folder))
                        {
                                var frag:String = folder + name + '.frag';
                                var vert:String = folder + name + '.vert';
                                var found:Bool = false;
                                if (FileSystem.exists(frag))
                                {
                                        frag = File.getContent(frag);
                                        found = true;
                                }
                                else
                                        frag = null;

                                if (FileSystem.exists(vert))
                                {
                                        vert = File.getContent(vert);
                                        found = true;
                                }
                                else
                                        vert = null;

                                if (found)
                                {
                                        PlayState.instance.runtimeShaders.set(name, [frag, vert]);
                                        // trace('Found shader $name!');
                                        return true;
                                }
                        }
                }
                luaTrace('Missing shader $name .frag AND .vert files!', false, false, FlxColor.RED);
                #else
                luaTrace('This platform doesn\'t support Runtime Shaders!', false, false, FlxColor.RED);
                #end
                return false;
        }

        function getGroupStuff(leArray:Dynamic, variable:String)
        {
                var killMe:Array<String> = variable.split('.');
                if (killMe.length > 1)
                {
                        var coverMeInPiss:Dynamic = Reflect.getProperty(leArray, killMe[0]);
                        for (i in 1...killMe.length - 1)
                        {
                                coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
                        }
                        switch (Type.typeof(coverMeInPiss))
                        {
                                case ValueType.TClass(haxe.ds.StringMap) | ValueType.TClass(haxe.ds.ObjectMap) | ValueType.TClass(haxe.ds.IntMap) | ValueType.TClass(haxe.ds.EnumValueMap):
                                        return coverMeInPiss.get(killMe[killMe.length - 1]);
                                default:
                                        return Reflect.getProperty(coverMeInPiss, killMe[killMe.length - 1]);
                        };
                }
                switch (Type.typeof(leArray))
                {
                        case ValueType.TClass(haxe.ds.StringMap) | ValueType.TClass(haxe.ds.ObjectMap) | ValueType.TClass(haxe.ds.IntMap) | ValueType.TClass(haxe.ds.EnumValueMap):
                                return leArray.get(variable);
                        default:
                                return Reflect.getProperty(leArray, variable);
                };
        }

        function loadFrames(spr:FlxSprite, image:String, spriteType:String)
        {
                switch (spriteType.toLowerCase().trim())
                {
                        case "texture" | "textureatlas" | "tex":
                                spr.frames = AtlasFrameMaker.construct(image);

                        case "texture_noaa" | "textureatlas_noaa" | "tex_noaa":
                                spr.frames = AtlasFrameMaker.construct(image, null, true);

                        case "packer" | "packeratlas" | "pac":
                                spr.frames = Paths.getPackerAtlas(image);

                        default:
                                spr.frames = Paths.getSparrowAtlas(image);
                }
        }

        function setGroupStuff(leArray:Dynamic, variable:String, value:Dynamic)
        {
                var killMe:Array<String> = variable.split('.');
                if (killMe.length > 1)
                {
                        var coverMeInPiss:Dynamic = Reflect.getProperty(leArray, killMe[0]);
                        for (i in 1...killMe.length - 1)
                        {
                                coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
                        }
                        Reflect.setProperty(coverMeInPiss, killMe[killMe.length - 1], value);
                        return;
                }
                Reflect.setProperty(leArray, variable, value);
        }

        function resetTextTag(tag:String)
        {
                if (!PlayState.instance.modchartTexts.exists(tag))
                {
                        return;
                }

                var pee:ModchartText = PlayState.instance.modchartTexts.get(tag);
                pee.kill();
                if (pee.wasAdded)
                {
                        PlayState.instance.remove(pee, true);
                }
                pee.destroy();
                PlayState.instance.modchartTexts.remove(tag);
        }

        function resetSpriteTag(tag:String)
        {
                if (!PlayState.instance.modchartSprites.exists(tag))
                {
                        return;
                }

                var pee:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
                pee.kill();
                if (pee.wasAdded)
                {
                        PlayState.instance.remove(pee, true);
                }
                pee.destroy();
                PlayState.instance.modchartSprites.remove(tag);
        }

        function cancelTween(tag:String)
        {
                if (PlayState.instance.modchartTweens.exists(tag))
                {
                        PlayState.instance.modchartTweens.get(tag).cancel();
                        PlayState.instance.modchartTweens.get(tag).destroy();
                        PlayState.instance.modchartTweens.remove(tag);
                }
        }

        function tweenShit(tag:String, vars:String)
        {
                cancelTween(tag);
                var variables:Array<String> = vars.split('.');
                var sexyProp:Dynamic = getObjectDirectly(variables[0]);
                if (variables.length > 1)
                {
                        sexyProp = getVarInArray(getPropertyLoopThingWhatever(variables), variables[variables.length - 1]);
                }
                return sexyProp;
        }

        function cancelTimer(tag:String)
        {
                if (PlayState.instance.modchartTimers.exists(tag))
                {
                        var theTimer:FlxTimer = PlayState.instance.modchartTimers.get(tag);
                        theTimer.cancel();
                        theTimer.destroy();
                        PlayState.instance.modchartTimers.remove(tag);
                }
        }

        // Better optimized than using some getProperty shit or idk
        function getFlxEaseByString(?ease:String = '')
        {
                switch (ease.toLowerCase().trim())
                {
                        case 'backin':
                                return FlxEase.backIn;
                        case 'backinout':
                                return FlxEase.backInOut;
                        case 'backout':
                                return FlxEase.backOut;
                        case 'bouncein':
                                return FlxEase.bounceIn;
                        case 'bounceinout':
                                return FlxEase.bounceInOut;
                        case 'bounceout':
                                return FlxEase.bounceOut;
                        case 'circin':
                                return FlxEase.circIn;
                        case 'circinout':
                                return FlxEase.circInOut;
                        case 'circout':
                                return FlxEase.circOut;
                        case 'cubein':
                                return FlxEase.cubeIn;
                        case 'cubeinout':
                                return FlxEase.cubeInOut;
                        case 'cubeout':
                                return FlxEase.cubeOut;
                        case 'elasticin':
                                return FlxEase.elasticIn;
                        case 'elasticinout':
                                return FlxEase.elasticInOut;
                        case 'elasticout':
                                return FlxEase.elasticOut;
                        case 'expoin':
                                return FlxEase.expoIn;
                        case 'expoinout':
                                return FlxEase.expoInOut;
                        case 'expoout':
                                return FlxEase.expoOut;
                        case 'quadin':
                                return FlxEase.quadIn;
                        case 'quadinout':
                                return FlxEase.quadInOut;
                        case 'quadout':
                                return FlxEase.quadOut;
                        case 'quartin':
                                return FlxEase.quartIn;
                        case 'quartinout':
                                return FlxEase.quartInOut;
                        case 'quartout':
                                return FlxEase.quartOut;
                        case 'quintin':
                                return FlxEase.quintIn;
                        case 'quintinout':
                                return FlxEase.quintInOut;
                        case 'quintout':
                                return FlxEase.quintOut;
                        case 'sinein':
                                return FlxEase.sineIn;
                        case 'sineinout':
                                return FlxEase.sineInOut;
                        case 'sineout':
                                return FlxEase.sineOut;
                        case 'smoothstepin':
                                return FlxEase.smoothStepIn;
                        case 'smoothstepinout':
                                return FlxEase.smoothStepInOut;
                        case 'smoothstepout':
                                return FlxEase.smoothStepInOut;
                        case 'smootherstepin':
                                return FlxEase.smootherStepIn;
                        case 'smootherstepinout':
                                return FlxEase.smootherStepInOut;
                        case 'smootherstepout':
                                return FlxEase.smootherStepOut;
                }
                return FlxEase.linear;
        }

        function blendModeFromString(blend:String):BlendMode
        {
                switch (blend.toLowerCase().trim())
                {
                        case 'add':
                                return ADD;
                        case 'alpha':
                                return ALPHA;
                        case 'darken':
                                return DARKEN;
                        case 'difference':
                                return DIFFERENCE;
                        case 'erase':
                                return ERASE;
                        case 'hardlight':
                                return HARDLIGHT;
                        case 'invert':
                                return INVERT;
                        case 'layer':
                                return LAYER;
                        case 'lighten':
                                return LIGHTEN;
                        case 'multiply':
                                return MULTIPLY;
                        case 'overlay':
                                return OVERLAY;
                        case 'screen':
                                return SCREEN;
                        case 'shader':
                                return SHADER;
                        case 'subtract':
                                return SUBTRACT;
                }
                return NORMAL;
        }

        function cameraFromString(cam:String):FlxCamera
        {
                switch (cam.toLowerCase())
                {
                        case 'camhud' | 'hud':
                                return PlayState.instance.camHUD;
                        case 'camother' | 'other':
                                return PlayState.instance.camOther;
                }
                return PlayState.instance.camGame;
        }

        public function luaTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false, color:FlxColor = FlxColor.WHITE)
        {
                #if LUA_ALLOWED
                if (ignoreCheck || getBool('luaDebugMode'))
                {
                        if (deprecated && !getBool('luaDeprecatedWarnings'))
                        {
                                return;
                        }
                        PlayState.instance.addTextToDebug(text, color);
                        trace(text);
                }
                #end
        }

        function getErrorMessage(status:Int):String
        {
                #if LUA_ALLOWED
                var v:String = Lua.tostring(lua, -1);
                Lua.pop(lua, 1);

                if (v != null)
                        v = v.trim();
                if (v == null || v == "")
                {
                        switch (status)
                        {
                                case Lua.LUA_ERRRUN:
                                        return "Runtime Error";
                                case Lua.LUA_ERRMEM:
                                        return "Memory Allocation Error";
                                case Lua.LUA_ERRERR:
                                        return "Critical Error";
                        }
                        return "Unknown Error";
                }

                return v;
                #end
                return null;
        }

        var lastCalledFunction:String = '';

        public function call(func:String, args:Array<Dynamic>):Dynamic
        {
                #if LUA_ALLOWED
                if (closed)
                        return Function_Continue;

                lastCalledFunction = func;
                try
                {
                        if (lua == null)
                                return Function_Continue;

                        Lua.getglobal(lua, func);
                        var type:Int = Lua.type(lua, -1);

                        if (type != Lua.LUA_TFUNCTION)
                        {
                                if (type > Lua.LUA_TNIL)
                                        luaTrace("ERROR (" + func + "): attempt to call a " + typeToString(type) + " value", false, false, FlxColor.RED);

                                Lua.pop(lua, 1);
                                return Function_Continue;
                        }

                        for (arg in args)
                                Convert.toLua(lua, arg);
                        var status:Int = Lua.pcall(lua, args.length, 1, 0);

                        // Checks if it's not successful, then show a error.
                        if (status != Lua.LUA_OK)
                        {
                                var error:String = getErrorMessage(status);
                                luaTrace("ERROR (" + func + "): " + error, false, false, FlxColor.RED);
                                return Function_Continue;
                        }

                        // If successful, pass and then return the result.
                        var result:Dynamic = cast Convert.fromLua(lua, -1);
                        if (result == null)
                                result = Function_Continue;

                        Lua.pop(lua, 1);
                        return result;
                }
                catch (e:Dynamic)
                {
                        trace(e);
                }
                #end
                return Function_Continue;
        }

        static function addAnimByIndices(obj:String, name:String, prefix:String, indices:String, framerate:Int = 24, loop:Bool = false)
        {
                var strIndices:Array<String> = indices.trim().split(',');
                var die:Array<Int> = [];
                for (i in 0...strIndices.length)
                {
                        die.push(Std.parseInt(strIndices[i]));
                }

                if (PlayState.instance.getLuaObject(obj, false) != null)
                {
                        var pussy:FlxSprite = PlayState.instance.getLuaObject(obj, false);
                        pussy.animation.addByIndices(name, prefix, die, '', framerate, loop);
                        if (pussy.animation.curAnim == null)
                        {
                                pussy.animation.play(name, true);
                        }
                        return true;
                }

                var pussy:FlxSprite = Reflect.getProperty(getInstance(), obj);
                if (pussy != null)
                {
                        pussy.animation.addByIndices(name, prefix, die, '', framerate, loop);
                        if (pussy.animation.curAnim == null)
                        {
                                pussy.animation.play(name, true);
                        }
                        return true;
                }
                return false;
        }

        public static function getPropertyLoopThingWhatever(killMe:Array<String>, ?checkForTextsToo:Bool = true, ?getProperty:Bool = true):Dynamic
        {
                var coverMeInPiss:Dynamic = getObjectDirectly(killMe[0], checkForTextsToo);
                var end = killMe.length;
                if (getProperty)
                        end = killMe.length - 1;

                for (i in 1...end)
                {
                        coverMeInPiss = getVarInArray(coverMeInPiss, killMe[i]);
                }
                return coverMeInPiss;
        }

        public static function getObjectDirectly(objectName:String, ?checkForTextsToo:Bool = true):Dynamic
        {
                var coverMeInPiss:Dynamic = PlayState.instance.getLuaObject(objectName, checkForTextsToo);
                if (coverMeInPiss == null)
                        coverMeInPiss = getVarInArray(getInstance(), objectName);

                return coverMeInPiss;
        }

        function typeToString(type:Int):String
        {
                #if LUA_ALLOWED
                switch (type)
                {
                        case Lua.LUA_TBOOLEAN:
                                return "boolean";
                        case Lua.LUA_TNUMBER:
                                return "number";
                        case Lua.LUA_TSTRING:
                                return "string";
                        case Lua.LUA_TTABLE:
                                return "table";
                        case Lua.LUA_TFUNCTION:
                                return "function";
                }
                if (type <= Lua.LUA_TNIL)
                        return "nil";
                #end
                return "unknown";
        }

        public function set(variable:String, data:Dynamic)
        {
                #if LUA_ALLOWED
                if (lua == null)
                {
                        return;
                }

                Convert.toLua(lua, data);
                Lua.setglobal(lua, variable);
                #end
        }

        #if LUA_ALLOWED
        public function getBool(variable:String)
        {
                var result:String = null;
                Lua.getglobal(lua, variable);
                result = Convert.fromLua(lua, -1);
                Lua.pop(lua, 1);

                if (result == null)
                {
                        return false;
                }
                return (result == 'true');
        }
        #end

        public function stop()
        {
                #if LUA_ALLOWED
                if (lua == null)
                {
                        return;
                }

                Lua.close(lua);
                lua = null;
                #end
        }

        public static inline function getInstance()
        {
                return PlayState.instance.isDead ? GameOverSubstate.instance : PlayState.instance;
        }
}

class ModchartSprite extends FlxSprite
{
        public var wasAdded:Bool = false;
        public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();

        // public var isInFront:Bool = false;

        public function new(?x:Float = 0, ?y:Float = 0)
        {
                super(x, y);
                antialiasing = ClientPrefs.globalAntialiasing;
        }
}

class ModchartText extends FlxText
{
        public var wasAdded:Bool = false;

        public function new(x:Float, y:Float, text:String, width:Float)
        {
                super(x, y, width, text, 16);
                setFormat(Paths.font("funkin.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
                cameras = [PlayState.instance.camHUD];
                scrollFactor.set();
                borderSize = 2;
        }
}

class DebugLuaText extends FlxText
{
        private var disableTime:Float = 6;

        public var parentGroup:FlxTypedGroup<DebugLuaText>;

        public function new(text:String, parentGroup:FlxTypedGroup<DebugLuaText>, color:FlxColor)
        {
                this.parentGroup = parentGroup;
                super(10, 10, 0, text, 16);
                setFormat(Paths.font("funkin.ttf"), 20, color, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
                scrollFactor.set();
                borderSize = 1;
        }

        override function update(elapsed:Float)
        {
                super.update(elapsed);
                disableTime -= elapsed;
                if (disableTime < 0)
                        disableTime = 0;
                if (disableTime < 1)
                        alpha = disableTime;
        }
}

class CustomSubstate extends MusicBeatSubstate
{
        public static var name:String = 'unnamed';
        public static var instance:CustomSubstate;

        override function create()
        {
                instance = this;

                PlayState.instance.callOnLuas('onCustomSubstateCreate', [name]);
                super.create();
                PlayState.instance.callOnLuas('onCustomSubstateCreatePost', [name]);
        }

        public function new(name:String)
        {
                CustomSubstate.name = name;
                super();
                cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
        }

        override function update(elapsed:Float)
        {
                PlayState.instance.callOnLuas('onCustomSubstateUpdate', [name, elapsed]);
                super.update(elapsed);
                PlayState.instance.callOnLuas('onCustomSubstateUpdatePost', [name, elapsed]);
        }

        override function destroy()
        {
                PlayState.instance.callOnLuas('onCustomSubstateDestroy', [name]);
                super.destroy();
        }
        #if mobile
        public static function insertLuaTpad(?pos:Int = -1)
        {
                if(instance != null)
                {
                        var tagObject:FlxObject = PlayState.instance.luaTouchPad;

                        if(tagObject != null)
                        {
                                if(pos < 0) instance.add(tagObject);
                                else instance.insert(pos, tagObject);
                                return true;
                        }
                }
                return false;
        }
        #end
}

#if hscript
class HScript
{
        public static var parser:Parser = new Parser();

        public var interp:Interp;

        public var variables(get, never):Map<String, Dynamic>;

        public function get_variables()
        {
                return interp.variables;
        }

        public function new()
        {
                interp = new Interp();
                interp.variables.set('FlxG', FlxG);
                interp.variables.set('FlxSprite', FlxSprite);
                interp.variables.set('FlxCamera', FlxCamera);
                interp.variables.set('FlxTimer', FlxTimer);
                interp.variables.set('FlxTween', FlxTween);
                interp.variables.set('FlxEase', FlxEase);
                interp.variables.set('PlayState', PlayState);
                interp.variables.set('game', PlayState.instance);
                interp.variables.set('Paths', Paths);
                interp.variables.set('Conductor', Conductor);
                interp.variables.set('ClientPrefs', ClientPrefs);
                interp.variables.set('Character', Character);
                interp.variables.set('Alphabet', Alphabet);
                interp.variables.set('CustomSubstate', CustomSubstate);
                #if (!flash && sys)
                interp.variables.set('FlxRuntimeShader', FlxRuntimeShader);
                #end
                interp.variables.set('ShaderFilter', openfl.filters.ShaderFilter);
                interp.variables.set('StringTools', StringTools);

                interp.variables.set('setVar', function(name:String, value:Dynamic)
                {
                        PlayState.instance.variables.set(name, value);
                });
                interp.variables.set('getVar', function(name:String)
                {
                        var result:Dynamic = null;
                        if (PlayState.instance.variables.exists(name))
                                result = PlayState.instance.variables.get(name);
                        return result;
                });
                interp.variables.set('removeVar', function(name:String)
                {
                        if (PlayState.instance.variables.exists(name))
                        {
                                PlayState.instance.variables.remove(name);
                                return true;
                        }
                        return false;
                });
        }

        public function execute(codeToRun:String):Dynamic
        {
                @:privateAccess
                HScript.parser.line = 1;
                HScript.parser.allowTypes = true;
                return interp.execute(HScript.parser.parseString(codeToRun));
        }
}
#end
