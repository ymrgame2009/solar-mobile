package;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import openfl.utils.Assets as OpenFlAssets;
#if sys
import sys.FileSystem;
#end

class GameOverSubstate extends MusicBeatSubstate
{
        public var boyfriend:Boyfriend;
        var camFollow:FlxPoint;
        var camFollowPos:FlxObject;
        var updateCamera:Bool = false;
        var playingDeathSound:Bool = false;

        var stageSuffix:String = "";

        public static var characterName:String = 'bf-dead';
        public static var deathSoundName:String = 'fnf_loss_sfx';
        public static var loopSoundName:String = 'gameOver';
        public static var endSoundName:String = 'gameOverEnd';

        public static var instance:GameOverSubstate;

        public static function resetVariables() {
                characterName = 'bf-dead';
                deathSoundName = 'fnf_loss_sfx';
                loopSoundName = 'gameOver';
                endSoundName = 'gameOverEnd';
        }

        override function create()
        {
                instance = this;
                PlayState.instance.callOnLuas('onGameOverStart', []);

                super.create();
        }

        public function new(x:Float, y:Float, camX:Float, camY:Float)
        {
                super();

                PlayState.instance.setOnLuas('inGameOver', true);

                Conductor.songPosition = 0;

                boyfriend = new Boyfriend(x, y, characterName);
                boyfriend.x += boyfriend.positionArray[0];
                boyfriend.y += boyfriend.positionArray[1];
                add(boyfriend);

                camFollow = new FlxPoint(boyfriend.getGraphicMidpoint().x, boyfriend.getGraphicMidpoint().y);

                FlxG.sound.play(Paths.sound(deathSoundName));
                Conductor.changeBPM(100);
                // FlxG.camera.followLerp = 1;
                // FlxG.camera.focusOn(FlxPoint.get(FlxG.width / 2, FlxG.height / 2));
                FlxG.camera.scroll.set();
                FlxG.camera.target = null;

                boyfriend.playAnim('firstDeath');

                camFollowPos = new FlxObject(0, 0, 1, 1);
                camFollowPos.setPosition(FlxG.camera.scroll.x + (FlxG.camera.width / 2), FlxG.camera.scroll.y + (FlxG.camera.height / 2));
                add(camFollowPos);

                #if mobile
                addTouchPad("NONE", "A_B");
                addTouchPadCamera();
                #end
        }

        var isFollowingAlready:Bool = false;
        override function update(elapsed:Float)
        {
                super.update(elapsed);

                PlayState.instance.callOnLuas('onUpdate', [elapsed]);
                if(updateCamera) {
                        var lerpVal:Float = CoolUtil.boundTo(elapsed * 0.6, 0, 1);
                        camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
                }

                if (controls.ACCEPT)
                {
                        endBullshit();
                }

                if (controls.BACK)
                {
                        FlxG.sound.music.stop();
                        PlayState.deathCounter = 0;
                        PlayState.seenCutscene = false;
                        PlayState.chartingMode = false;

                        WeekData.loadTheFirstEnabledMod();
                        if (PlayState.isStoryMode)
                                MusicBeatState.switchState(new StoryMenuState());
                        else
                                MusicBeatState.switchState(new FreeplayState());

                        FlxG.sound.playMusic(Paths.music("freakyMenu-" + ClientPrefs.mmm));
                        PlayState.instance.callOnLuas('onGameOverConfirm', [false]);
                }

                if (boyfriend.animation.curAnim != null && boyfriend.animation.curAnim.name == 'firstDeath')
                {
                        if(boyfriend.animation.curAnim.curFrame >= 12 && !isFollowingAlready)
                        {
                                FlxG.camera.follow(camFollowPos, LOCKON, 1);
                                updateCamera = true;
                                isFollowingAlready = true;
                        }

                        if (boyfriend.animation.curAnim.finished && !playingDeathSound)
                        {
                                if (PlayState.SONG.stage == 'tank')
                                {
                                        playingDeathSound = true;
                                        coolStartDeath(0.2);
                                        
                                        var exclude:Array<Int> = [];
                                        try {
                                                FlxG.sound.play(Paths.sound('jeffGameover/jeffGameover-' + FlxG.random.int(1, 25, exclude)), 1, false, null, true, function() {
                                                        if(!isEnding)
                                                        {
                                                                FlxG.sound.music.fadeIn(0.2, 1, 4);
                                                        }
                                                });
                                        } catch(e:Dynamic) {
                                                PlayState.logProgress('jeffGameover sound CRASH: ' + Std.string(e));
                                        }
                                }
                                else
                                {
                                        coolStartDeath();
                                }
                                boyfriend.startedDeath = true;
                        }
                }

                if (FlxG.sound.music.playing)
                {
                        Conductor.songPosition = FlxG.sound.music.time;
                }
                PlayState.instance.callOnLuas('onUpdatePost', [elapsed]);
        }

        override function beatHit()
        {
                super.beatHit();

                //FlxG.log.add('beat');
        }

        var isEnding:Bool = false;

        function coolStartDeath(?volume:Float = 1):Void
        {
                try {
                        PlayState.logProgress('coolStartDeath: loading ' + loopSoundName + ' from shared');
                        var snd = Paths.music(loopSoundName, 'shared');
                        if (snd == null) {
                                PlayState.logProgress('coolStartDeath: not in shared, trying default');
                                snd = Paths.music(loopSoundName);
                        }
                        if (snd != null) {
                                FlxG.sound.playMusic(snd, volume);
                                PlayState.logProgress('coolStartDeath: OK');
                        } else {
                                PlayState.logProgress('coolStartDeath: sound is null, skipping');
                        }
                } catch(e:Dynamic) {
                        PlayState.logProgress('coolStartDeath CRASH: ' + Std.string(e));
                }
        }

        function endBullshit():Void
        {
                if (!isEnding)
                {
                        isEnding = true;
                        try {
                                boyfriend.playAnim('deathConfirm', true);
                                FlxG.sound.music.stop();
                                try {
                                        var endSnd = Paths.music(endSoundName, 'shared');
                                        if (endSnd == null) endSnd = Paths.music(endSoundName);
                                        if (endSnd != null) FlxG.sound.play(endSnd);
                                } catch(e:Dynamic) {
                                        PlayState.logProgress('endBullshit sound CRASH: ' + Std.string(e));
                                }
                        } catch(e:Dynamic) {
                                PlayState.logProgress('endBullshit sound CRASH: ' + Std.string(e));
                        }
                        new FlxTimer().start(0.7, function(tmr:FlxTimer)
                        {
                                FlxG.camera.fade(FlxColor.BLACK, 2, false, function()
                                {
                                        try {
                                                MusicBeatState.resetState();
                                        } catch(e:Dynamic) {
                                                PlayState.logProgress('resetState CRASH: ' + Std.string(e));
                                                FlxG.resetState();
                                        }
                                });
                        });
                        PlayState.instance.callOnLuas('onGameOverConfirm', [true]);
                }
        }
}
