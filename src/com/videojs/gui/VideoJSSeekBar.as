package com.videojs.gui 
{
	import com.videojs.VideoJSConsole;
	import com.videojs.VideoJSModel;
	import flash.display.DisplayObject;
	import flash.display.GradientType;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.filters.BitmapFilterQuality;
	import flash.filters.DropShadowFilter;
	import flash.geom.Matrix;
	import flash.utils.Timer;
	
	/**
	 * Fallback GUI for the seek bar (including buffer visualization)
	 * @author Justin Bosar
	 */
	public class VideoJSSeekBar extends Sprite 
	{
		private static const DEFAULT_WIDTH:uint = 60;
		private static const DEFAULT_HEIGHT:uint = 9;
		private var colorRange:uint;
		private var colorPlayed:uint;
		private var colorBuffered:uint;
		private var headIcon:DisplayObject;
		private var currentWidth:uint;
		private var _model:VideoJSModel;
		private var displayBuffer:Shape;
		private var displayPlayed:Shape;
		private var isDragging:Boolean;
		private var seekTimer:Timer;
		private var isTempPause:Boolean;
		
		/**
		 * Constructor
		 * 
		 * @param	icon art used to represent the playhead
		 * @param	range background color for the playable range
		 * @param	played foreground color for the range that's already been played
		 * @param	buffered color for the range that has been buffered
		 */
		public function VideoJSSeekBar(icon:DisplayObject, range:uint = 0x333333, played:uint = 0xCCCCCC, buffered:uint = 0x666666) 
		{
			super();
			headIcon = icon;
			colorRange = range;
			colorPlayed = played;
			colorBuffered = buffered;
			_model = VideoJSModel.getInstance();
			isDragging = false;
			isTempPause = false;
			
			// init graphics
			var matrix:Matrix = new Matrix();
			matrix.createGradientBox(DEFAULT_WIDTH, DEFAULT_HEIGHT, Math.PI / 2);
			displayBuffer = new Shape();
			this.addChild(displayBuffer);
			displayPlayed = new Shape();
			displayPlayed.graphics.beginGradientFill(GradientType.LINEAR, [colorPlayed, colorPlayed], [1, 1], [0, 255], matrix);
			displayPlayed.graphics.drawRect(0, 0, DEFAULT_WIDTH, DEFAULT_HEIGHT);
			displayPlayed.graphics.endFill();
			displayPlayed.x = DEFAULT_HEIGHT / 2;
			this.addChild(displayPlayed);
			if (headIcon.height > DEFAULT_HEIGHT)
			{
				headIcon.y = Math.round(0 - (headIcon.height - DEFAULT_HEIGHT) / 2);
			}
			headIcon.filters = [new DropShadowFilter(2, 90, 0x000000, 0.5, 6, 6, 2, BitmapFilterQuality.MEDIUM)];
			this.addChild(headIcon);
			redraw(DEFAULT_WIDTH);
			
			this.addEventListener(MouseEvent.MOUSE_DOWN, startSeek);
			seekTimer = new Timer(VideoJSGUI.REDRAW_SPEED);
			seekTimer.addEventListener(TimerEvent.TIMER, updateSeek);
			this.buttonMode = true;
			this.mouseChildren = false;
		}
		
		/**
		 * if the player is trying to use the seek bar to navigate the video, begin tracking
		 * 
		 * @param	evt typically MOUSE_DOWN input
		 */
		private function startSeek(evt:MouseEvent = null):void
		{
			if (VideoJS.ALLOW_CONSOLE) VideoJSConsole.log("startSeek");
			isDragging = true;
			if (stage != null)
			{
				if (!stage.hasEventListener(MouseEvent.MOUSE_UP))
				{
					stage.addEventListener(MouseEvent.MOUSE_UP, endSeek);
				}
				if (_model.playing)
				{
					_model.pause();
					isTempPause = true;
				}
				updateSeek();
			}
			seekTimer.reset();
			seekTimer.start();
		}
		
		/**
		 * when the user stops seeking, play from the new spot (if it was playing before)
		 * 
		 * @param	evt typically MOUSE_UP input
		 */
		private function endSeek(evt:MouseEvent = null):void
		{
			if (isDragging)
			{
				if (VideoJS.ALLOW_CONSOLE) VideoJSConsole.log("endSeek");
				isDragging = false;
				if (isTempPause)
				{
					_model.play();
					isTempPause = false;
				}
			}
		}
		
		/**
		 * during a drag-to-seek operation, periodically request a new position in the video stream
		 * 
		 * @param	evt timed update
		 */
		private function updateSeek(evt:TimerEvent = null):void
		{
			if (isDragging)
			{
				if (stage != null)
				{
					// check range bounds
					var posInPixels:uint = Math.max(0, stage.mouseX - this.x);
					if (posInPixels > currentWidth) posInPixels = currentWidth;
					
					// ask for seek
					var posInTime:Number = posInPixels / currentWidth * _model.duration;
					if (VideoJS.ALLOW_CONSOLE) VideoJSConsole.log("updateSeek: " + posInPixels + " " + posInTime + " " + stage.mouseX + " " + stage.mouseY);
					_model.seekBySeconds(posInTime);
				}
				else 
				{
					endSeek();
				}
			}
		}
		
		/**
		 * draw the background shapes at a given width
		 * 
		 * @param	width new total length for the seek-able area
		 */
		internal function redraw(width:uint = 60):void
		{
			currentWidth = width;
			var colors:Array;
			var matrix:Matrix = new Matrix();
			matrix.createGradientBox(width, DEFAULT_HEIGHT, Math.PI / 2);
			graphics.clear();
			colors = [0x111111, colorRange];
			graphics.beginGradientFill(GradientType.LINEAR, colors, [1, 1], [0, 255], matrix);
			graphics.drawRoundRect(0, 0, currentWidth, DEFAULT_HEIGHT, DEFAULT_HEIGHT);
			graphics.endFill();
			colors = [colorPlayed, colorPlayed];
			graphics.beginGradientFill(GradientType.LINEAR, colors, [1, 1], [0, 255], matrix);
			graphics.drawRoundRect(0, 0, DEFAULT_HEIGHT, DEFAULT_HEIGHT, DEFAULT_HEIGHT);
			graphics.endFill();
		}
		
		/**
		 * redraw the graphics based on the model's current state
		 * 
		 * @param	evt timed update
		 */
		internal function updateHead(evt:Event = null):void
		{
			var headPos:int = (_model.time / _model.duration) * (currentWidth - headIcon.width + 3);
			headIcon.x = headPos;
			displayPlayed.width = headPos;
			
			// draw buffered range
			var bufferPos:int = (_model.buffered / _model.duration) * currentWidth - DEFAULT_HEIGHT;
			var matrix:Matrix = new Matrix();
			matrix.createGradientBox(currentWidth, DEFAULT_HEIGHT, Math.PI / 2);
			displayBuffer.graphics.clear();
			displayBuffer.graphics.beginGradientFill(GradientType.LINEAR, [colorBuffered, colorRange], [1, 1], [0, 255], matrix);
			displayBuffer.graphics.drawRoundRect(DEFAULT_HEIGHT, 0, bufferPos, DEFAULT_HEIGHT, DEFAULT_HEIGHT);
			displayBuffer.graphics.endFill();
		}
		
	}

}