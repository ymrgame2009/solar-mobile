package;

import sys.TempStateData;
import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import openfl.Assets;
import openfl.Lib;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;
#if mobile
import mobile.CopyState;
#end

//crash handler stuff
import lime.app.Application;
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end
import sys.FileSystem;
import sys.io.File;

using StringTools;

class Main extends Sprite
{
        var gameWidth:Int = 1280; // Width of the game in pixels (might be less / more in actual pixels depending on your zoom).
        var gameHeight:Int = 720; // Height of the game in pixels (might be less / more in actual pixels depending on your zoom).
        var initialState:Class<FlxState> = InitState; // The FlxState the game starts with.
        var zoom:Float = -1; // If -1, zoom is automatically calculated to fit the window dimensions.
        var framerate:Int = 60; // How many frames per second the game should run at.
        var skipSplash:Bool = true; // Whether to skip the flixel splash screen that appears in release mode.
        var startFullscreen:Bool = false; // Whether to start the game in fullscreen on desktop targets
        public static var fpsVar:FPS;

        // You can pretty much ignore everything from here on - your code should go in your states.

        public static function main():Void
        {
                Lib.current.addChild(new Main());
        }

        public function new()
        {

                                #if mobile
                #if android
                StorageUtil.requestPermissions();
                #end
                Sys.setCwd(StorageUtil.getStorageDirectory());
                #end
                super();

                if (stage != null)
                {
                        init();
                }
                else
                {
                        addEventListener(Event.ADDED_TO_STAGE, init);
                }
        }

        private function init(?E:Event):Void
        {
                if (hasEventListener(Event.ADDED_TO_STAGE))
                {
                        removeEventListener(Event.ADDED_TO_STAGE, init);
                }

                setupGame();
        }

        private function setupGame():Void
        {
                var stageWidth:Int = Lib.current.stage.stageWidth;
                var stageHeight:Int = Lib.current.stage.stageHeight;

                if (zoom == -1)
                {
                        var ratioX:Float = stageWidth / gameWidth;
                        var ratioY:Float = stageHeight / gameHeight;
                        zoom = Math.min(ratioX, ratioY);
                        gameWidth = Math.ceil(stageWidth / zoom);
                        gameHeight = Math.ceil(stageHeight / zoom);
                }
        
                ClientPrefs.loadDefaultStuff();
                //SUtil.checkFiles();
                addChild(new FlxGame(gameWidth, gameHeight, initialState, framerate, framerate, skipSplash, startFullscreen));
                new TempStateData();

                #if !mobile
                fpsVar = new FPS(10, 3, 0xFFFFFF);
                addChild(fpsVar);
                Lib.current.stage.align = "tl";
                Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
                if(fpsVar != null) {
                        fpsVar.visible = ClientPrefs.showFPS;
                }
                #end

                #if android
                FlxG.android.preventDefaultKeys = [BACK];
                #end

                #if html5
                FlxG.autoPause = false;
                FlxG.mouse.visible = false;
                #end
                
                // Always register crash handler (on sys targets) so we get a log file
                #if sys
                Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
                #end

                #if mobile
                lime.system.System.allowScreenTimeout = ClientPrefs.screensaver;
                #if android
                FlxG.android.preventDefaultKeys = [BACK]; 
                #end
                #end
        }

        // Code was entirely made by sqirra-rng for their fnf engine named "Izzy Engine", big props to them!!!
        // very cool person for real they don't get enough credit for their work
        #if sys
        function onCrash(e:UncaughtErrorEvent):Void
        {
                var errMsg:String = "";
                var path:String;
                var callStack:Array<haxe.CallStack.StackItem> = CallStack.exceptionStack(true);
                var dateNow:String = Date.now().toString();

                dateNow = dateNow.replace(" ", "_");
                dateNow = dateNow.replace(":", "'");

                path = "./crash/" + "SolarEngine_" + dateNow + ".txt";

                for (stackItem in callStack)
                {
                        switch (stackItem)
                        {
                                case FilePos(s, file, line, column):
                                        errMsg += file + " (line " + line + ")\n";
                                default:
                                        Sys.println(stackItem);
                        }
                }

                errMsg += "\nUncaught Error: " + e.error + "\nPlease report this error to the GitHub page: https://github.com/VideoBotYT/Universe-Engine\n\n> Crash Handler written by: sqirra-rng";

                try
                {
                        if (!FileSystem.exists("./crash/"))
                                FileSystem.createDirectory("./crash/");
                        File.saveContent(path, errMsg + "\n");
                        Sys.println(errMsg);
                        Sys.println("Crash dump saved in " + Path.normalize(path));
                }
                catch (e2:Dynamic)
                {
                        Sys.println("Failed to save crash dump: " + e2);
                }

                // Only show alert on desktop (mobile doesn't have window.alert)
                #if desktop
                try { Application.current.window.alert(errMsg, "Error!"); } catch (e3:Dynamic) {}
                try { DiscordClient.shutdown(); } catch (e4:Dynamic) {}
                #elseif mobile
                // On mobile, try to show a toast/popup if available
                try { lime.app.Application.current.window.alert(errMsg, "Error!"); } catch (e3:Dynamic) {}
                #end
                Sys.exit(1);
        }
        #end
}
