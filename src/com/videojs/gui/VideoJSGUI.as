package com.videojs.gui 
{
	import com.videojs.events.VideoPlaybackEvent;
	import com.videojs.VideoJSConsole;
	import com.videojs.VideoJSModel;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.GradientType;
	import flash.display.Graphics;
	import flash.display.Loader;
	import flash.display.PixelSnapping;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.display.StageDisplayState;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.net.URLRequest;
	import flash.system.LoaderContext;
	import flash.text.StyleSheet;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	import flash.utils.Timer;
	
	/**
	 * Main class for fallback GUI rendered by Flash, in case the JS GUI is struggling (old IE, true fullscreen, etc)
	 * @author Justin Bosar
	 */
	public class VideoJSGUI extends Sprite 
	{
		[Embed(source = "video-js.png")]
		private static var SpriteSheet:Class;  // button icons
		
		/**
		 * milliseconds between UI sync attempts
		 */
		internal static const REDRAW_SPEED:uint = 200;
		
		/**
		 * total height of the controls area
		 */
		private static const DEFAULT_SCALE:uint = 40;
		
		/**
		 * area reserved to the left and right of the seek bar (for duration display)
		 */
		private static const SEEK_PAD:uint = 48; 
		
		/**
		 * url for a logo image to apply to the upper left (optional)
		 */
		public static var logoURL:String = "";
		
		/**
		 * optional imported rules for drawing the GUI
		 */
		internal static var style:StyleSheet;
		
		/**
		 * player state info
		 */
		internal static var _model:VideoJSModel;
		
		private static var _instance:VideoJSGUI;
		private static var _isFullscreen:Boolean;
		
		// controls
		private static var play:VideoJSToggleButton;
		private static var mute:VideoJSToggleButton;
		private static var fullscreen:VideoJSToggleButton;
		private static var seek:VideoJSSeekBar;
		private static var volume:VideoJSVolume;
		
		private var theme:VideoJSTheme;
		private var background:Shape;
		private var syncTimer:Timer;
		private var fadeTimer:Timer;
		private var fadePos:Point; // mouse coords during last fade tick
		private var timePlayed:TextField;
		private var timeRemaining:TextField;
		private var volumeBeforeMute:Number;
		private var logo:Loader;
		
		private static var isBitmapReady:Boolean = false;
		private static var isStyleReady:Boolean = false;
		
		/**
		 * Constructor
		 */
		public function VideoJSGUI() 
		{
			super();
			_instance = this;
			_isFullscreen = false;
			_model = VideoJSModel.getInstance();
			volumeBeforeMute = _model.volume;
			visible = false;
			
			// TODO perhaps button icons should be loaded async instead of embedded, to allow better customization
			if (!isBitmapReady) createButtons();
		}
		
		/**
		 * carve sprite sheet into bitmap data for the icons and create buttons
		 */
		private static function createButtons():void
		{
			var source:Bitmap = new SpriteSheet();
			var carver:Rectangle;
			var bmd:BitmapData;
			var bmdAlt:BitmapData;
			var pos:Point = new Point();
			
			// play/pause
			carver = new Rectangle(0, 0, 20, 18); 
			bmd = new BitmapData(carver.width, carver.height, true, 0x00000000);
			bmd.copyPixels(source.bitmapData, carver, pos, null, null, true);
			carver = new Rectangle(25, 0, 20, 18);
			bmdAlt = new BitmapData(carver.width, carver.height, true, 0x00000000);
			bmdAlt.copyPixels(source.bitmapData, carver, pos, null, null, true);
			play = new VideoJSToggleButton(new Bitmap(bmd, PixelSnapping.ALWAYS), new Bitmap(bmdAlt, PixelSnapping.ALWAYS), onTogglePlay);
			
			// toggle fullscreen
			carver = new Rectangle(50, 0, 20, 18);
			bmd = new BitmapData(carver.width, carver.height, true, 0x00000000);
			bmd.copyPixels(source.bitmapData, carver, pos, null, null, true);
			carver = new Rectangle(75, 0, 20, 18);
			bmdAlt = new BitmapData(carver.width, carver.height, true, 0x00000000);
			bmdAlt.copyPixels(source.bitmapData, carver, pos, null, null, true);
			fullscreen = new VideoJSToggleButton(new Bitmap(bmd, PixelSnapping.ALWAYS), new Bitmap(bmdAlt, PixelSnapping.ALWAYS), onToggleFullscreen);
			
			// toggle mute
			carver = new Rectangle(50, 25, 20, 18);
			bmd = new BitmapData(carver.width, carver.height, true, 0x00000000);
			bmd.copyPixels(source.bitmapData, carver, pos, null, null, true);
			carver = new Rectangle(0, 25, 20, 18);
			bmdAlt = new BitmapData(carver.width, carver.height, true, 0x00000000);
			bmdAlt.copyPixels(source.bitmapData, carver, pos, null, null, true);
			mute = new VideoJSToggleButton(new Bitmap(bmd, PixelSnapping.ALWAYS), new Bitmap(bmdAlt, PixelSnapping.ALWAYS), onToggleMute);
			
			// playhead / range
			carver = new Rectangle(0, 50, 18, 18);
			bmd = new BitmapData(carver.width, carver.height, true, 0x00000000);
			bmd.copyPixels(source.bitmapData, carver, pos, null, null, true);
			seek = new VideoJSSeekBar(new Bitmap(bmd, PixelSnapping.ALWAYS));
			
			// volume
			volume = new VideoJSVolume();
			
			isBitmapReady = true;
			instance.loadStyle("");
		}
		
		/**
		 * check for some style rules specified outside the .swf
		 * 
		 * @param	stylePath URL of a CSS file
		 */
		private function loadStyle(stylePath:String):void
		{
			if (stylePath != "")
			{
				// TODO load stylesheet async
				theme = new VideoJSTheme(stylePath, onStyleReady);
			}
			else
			{
				theme = new VideoJSTheme();
				onStyleReady();
			}
			
			// if a logo watermark is requested, try loading it async
			if (logoURL != "")
			{
				logo = new Loader();
				var context:LoaderContext = new LoaderContext(true);
				var req:URLRequest = new URLRequest(logoURL);
				logo.contentLoaderInfo.addEventListener(Event.COMPLETE, addLogo);
				logo.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);
				logo.contentLoaderInfo.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onLoadSecurityError);
				//logo.load(req, context);
				try { logo.load(req, context); }
				catch (e:Error) {
					if (VideoJS.ALLOW_CONSOLE) VideoJSConsole.log("ERROR (logo load): " + e);
				}
			}
		}
		
		private function onLoadError(evt:IOErrorEvent):void
		{
			if (VideoJS.ALLOW_CONSOLE) VideoJSConsole.log("ERROR (logo load): " + evt.toString());
		}
		
		private function onLoadSecurityError(evt:SecurityErrorEvent):void
		{
			if (VideoJS.ALLOW_CONSOLE) VideoJSConsole.log("ERROR (logo load): " + evt.toString());
		}
		
		private function addLogo(evt:Event = null):void
		{
			if (logo != null)
			{
				logo.contentLoaderInfo.removeEventListener(Event.COMPLETE, addLogo);
				logo.mouseEnabled = false;
				logo.mouseChildren = false;
				logo.alpha = 0.5;
				positionLogo();
				this.addChild(logo);
			}
		}
		
		private function positionLogo():void
		{
			if ((logo != null) && (background != null))
			{
				logo.x = background.width - logo.width;
				logo.y = 0 - this.y;
				if (_isFullscreen || VideoJS.useFlashUI) logo.visible = true;
				else logo.visible = false;
			}
		}
		
		/**
		 * draw the background and add controls to the display list
		 * 
		 * @param	evt optional event indicating that the async CSS load is complete
		 */
		private function onStyleReady(evt:Event = null):void
		{
			isStyleReady = true;
			
			// TODO set stylesheet
			if (evt != null)
			{
				
			}
			
			background = new Shape();
			var pen:Graphics = background.graphics;
			var matrix:Matrix = new Matrix();
			matrix.createGradientBox(DEFAULT_SCALE, 10, Math.PI / 2);
			// TODO read colors from stylesheet
			var gradientColors:Array = [theme.colorBgSeekTop, theme.colorBgSeekBottom];
			pen.beginGradientFill(GradientType.LINEAR, gradientColors, [1, 1], [0, 255], matrix);
			pen.drawRect(0, 0, DEFAULT_SCALE, 10);
			pen.endFill();
			pen.beginFill(theme.colorBgBorderTop);
			pen.drawRect(0, 10, DEFAULT_SCALE, 1);
			pen.endFill();
			pen.beginFill(theme.colorBgBorderBottom);
			pen.drawRect(0, 11, DEFAULT_SCALE, 1);
			pen.endFill();
			pen.beginFill(0x242424);
			pen.drawRect(0, 12, DEFAULT_SCALE, Math.round((DEFAULT_SCALE - 12) / 2));
			pen.endFill();
			matrix.createGradientBox(DEFAULT_SCALE, Math.round((DEFAULT_SCALE - 12) / 2), Math.PI / 2);
			gradientColors = [0x1E1E1E, 0x171717];
			pen.beginGradientFill(GradientType.LINEAR, gradientColors, [1, 1], [0, 255], matrix);
			pen.drawRect(0, 12 + Math.round((DEFAULT_SCALE - 12) / 2), DEFAULT_SCALE, Math.round((DEFAULT_SCALE - 12) / 2));
			pen.endFill();
			this.addChild(background);
			
			// time played/remaining labels
			var style:TextFormat = new TextFormat("arial", 9, 0xCCCCCC);
			style.align = TextFormatAlign.CENTER;
			timePlayed = new TextField();
			timePlayed.defaultTextFormat = style;
			timePlayed.mouseEnabled = false;
			timePlayed.selectable = false;
			timePlayed.width = SEEK_PAD;
			timePlayed.height = 14;
			this.addChild(timePlayed);
			timeRemaining = new TextField();
			timeRemaining.defaultTextFormat = style;
			timeRemaining.mouseEnabled = false;
			timeRemaining.selectable = false;
			timeRemaining.width = SEEK_PAD;
			timeRemaining.height = 14;
			this.addChild(timeRemaining);
			timePlayed.y = timeRemaining.y = 0 - 2;
			
			// add controls to display list and position
			this.addChild(seek);
			seek.x = SEEK_PAD;
			seek.y = 1;
			this.addChild(play);
			this.addChild(mute);
			this.addChild(volume);
			this.addChild(fullscreen);
			play.y = mute.y = fullscreen.y = Math.round(DEFAULT_SCALE * 0.44);
			volume.y = Math.round(mute.y + mute.height / 2 - volume.height / 2);
			setSize(_model.stageRect.width, _model.stageRect.height);
			
			// update GUI based on model a few times per second
			syncTimer = new Timer(REDRAW_SPEED);
			syncTimer.addEventListener(TimerEvent.TIMER, updateDisplay);
			syncTimer.start();
			
			// fade GUI based on mouse movements
			fadeTimer = new Timer(100);
			fadeTimer.addEventListener(TimerEvent.TIMER, updateFade);
			fadeTimer.start();
			
			// watch for a finished clip
			_model.addEventListener(VideoPlaybackEvent.ON_STREAM_CLOSE, onMediaEnd);
		}
		
		/**
		 * fade the GUI based on certain mouse conditions
		 * 
		 * @param	evt timed update
		 */
		private function updateFade(evt:Event):void
		{
			if (stage == null) return;
			if (fadePos == null) fadePos = new Point();
			var isMouseMoving:Boolean = ((int(stage.mouseX) != fadePos.x) || (int(stage.mouseY) != fadePos.y));
			var isMouseOverVideo:Boolean = _model.stageRect.contains(stage.mouseX, stage.mouseY);
			var isMouseOverControls:Boolean = background.getBounds(stage).contains(stage.mouseX, stage.mouseY);
			//trace("updateFade: ", isMouseMoving, isMouseOverVideo, isFullscreen);
			if (isFullscreen)
			{
				if (isMouseMoving || isMouseOverControls) alpha = (alpha < 1.5) ? (alpha + 0.25) : 1.5;
				else alpha = (alpha > 0) ? (alpha - 0.1) : 0;
			}
			else
			{
				if (isMouseOverVideo) alpha = (alpha < 1.5) ? (alpha + 0.25) : 1.5;
				else alpha = (alpha > 0) ? (alpha - 0.1) : 0;
			}
			fadePos.x = stage.mouseX;
			fadePos.y = stage.mouseY;
		}
		
		/**
		 * When playback is finished, we'll need to drop out of fullscreen automatically
		 * 
		 * @param	evt typically the ON_STREAM_CLOSE event
		 */
		private function onMediaEnd(evt:Event):void
		{
			if (isFullscreen) onToggleFullscreen(false);
		}
		
		/**
		 * Because many many things can change the playing states, we must occasionally check to see if the GUI is out of sync
		 * 
		 * @param	evt usually triggered a few times a second by a timer
		 */
		private function updateDisplay(evt:TimerEvent = null):void
		{
			if (play.state != _model.playing) play.force(_model.playing);
			if (play.state && _model.paused) play.force(!_model.paused); // shouldn't be needed, but after pausing, _model.playing is sometimes still true...
			if (mute.state != _model.muted) mute.force(_model.muted);
			if (fullscreen.state != isFullscreen) fullscreen.force(isFullscreen);
			
			seek.updateHead();
			volume.update();
			timePlayed.text = formatTime(_model.time);
			timeRemaining.text = "-" + formatTime(_model.duration - Math.floor(_model.time));
		}
		
		/**
		 * set the correct player state in response to the user clicking the play/pause button
		 * 
		 * @param	state the new state of the button
		 */
		private static function onTogglePlay(state:Boolean):void
		{
			if (VideoJS.ALLOW_CONSOLE) VideoJSConsole.log("onTogglePlay: " + state + " " + _model.playing + " " + _model.paused);
			if (state)
			{
				if (_model.paused) _model.resume();
				else _model.play();
			}
			else
			{
				_model.pause();
			}
			// note: in the model, "playing" and "paused" are not mutually exclusive...
		}
		
		/**
		 * set the correct player state in response to the user clicking the mute button
		 * 
		 * @param	state the new state of the button
		 */
		private static function onToggleMute(state:Boolean):void
		{
			if (state && !_model.muted) 
			{
				// try to remember the volume so we can go back to it if they toggle mute again
				if (_instance != null) _instance.volumeBeforeMute = _model.volume;
				_model.volume = 0;
			}
			else
			{
				_model.muted = false;
				if (_instance != null) _model.volume = _instance.volumeBeforeMute;
			}
		}
		
		/**
		 * Handle a fullscreen state change
		 * 
		 * @param	state target state (send true to enable fullscreen mode)
		 */
		public static function onToggleFullscreen(state:Boolean):void
		{
			if (state != isFullscreen)
			{
				_isFullscreen = state;
				if (instance.stage != null)
				{
					instance.stage.displayState = _isFullscreen ? StageDisplayState.FULL_SCREEN : StageDisplayState.NORMAL;
				}
			}
		}
		
		/**
		 * true if we're currently displaying in fullscreen mode
		 */
		public static function get isFullscreen():Boolean
		{
			return _isFullscreen;
		}
		
		/**
		 * redraw the GUI after a resize event (like toggle fullscreen)
		 * 
		 * @param	width new control bar width (usually, new stage width)
		 * @param	verticalPosition new y coordinate for the gui (usually, new stage height)
		 */
		public function setSize(width:uint = 100, verticalPosition:uint = 100):void
		{
			if (background != null) background.width = width;
			if (stage != null)
			{
				_isFullscreen = (stage.displayState == StageDisplayState.FULL_SCREEN);
			}
			
			if (isBitmapReady && isStyleReady)
			{
				play.x = 18;
				mute.x = width - 117;
				fullscreen.x = width - fullscreen.width - 6;
				seek.redraw(width - SEEK_PAD * 2);
				timeRemaining.x = width - SEEK_PAD;
				volume.x = mute.x + mute.width + 9;
			}
			
			// toggle display of Flash GUI on fullscreen events unless forced from FlashVars
			visible = true;
			if (_isFullscreen || VideoJS.useFlashUI)
			{
				this.y = verticalPosition - DEFAULT_SCALE;
				if (!visible)
				{
					visible = mouseEnabled = mouseChildren = true;
				}
			}
			else
			{
				this.y = verticalPosition - DEFAULT_SCALE;
				if (visible)
				{
					//visible = mouseEnabled = mouseChildren = false;
				}
			}
			positionLogo();
		}
		
		/**
		 * Turn a number-of-seconds duration into a more readable label
		 * 
		 * @param	rawSeconds duration in seconds
		 * @return formatted version
		 */
		public static function formatTime(rawSeconds:Number = 0):String
		{
			var seconds:uint = Math.floor(rawSeconds);
			var h:uint = Math.floor(seconds / 3600);
			var m:uint = Math.floor((seconds % 3600) / 60);
			var s:uint = seconds % 60;
			var time:String = "";
			if (h > 0) time += h + ":";
			time += m + ":";
			time += ((s < 10) ? "0" : "") + s;
			return time;
		}
		
		/**
		 * utility function that slightly darkens an RGB color (useful for creating consistent "bevel" gradients)
		 * 
		 * @param	input starting color
		 * @return darker version of starting color
		 */
		public static function fadeColor(input:uint = 0xFFFFFF):uint
		{
			var ratio:Number = 0.7;
			var r:int = (input >> 16 & 0xFF) * ratio;
			var g:int = (input >> 8 & 0xFF) * ratio;
			var b:int = (input & 0xFF) * ratio;
			return (r << 16) + (g << 8) + b;
		}
		
		/**
		 * get a GUI object (creates one if the constructor has never been run before)
		 */
		public static function get instance():VideoJSGUI
		{
			if (_instance == null) _instance = new VideoJSGUI();
			return _instance;
		}
	}

}