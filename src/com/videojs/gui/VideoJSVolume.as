package com.videojs.gui 
{
	import com.videojs.VideoJSModel;
	import flash.display.GradientType;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Matrix;
	
	/**
	 * Flash version of the volume slider
	 * @author Justin Bosar
	 */
	public class VideoJSVolume extends Sprite 
	{
		private static const DEFAULT_HEIGHT:uint = 6;
		
		private var colorOff:uint;
		private var colorOn:uint;
		private var currentWidth:uint;
		private var icon:Shape;
		private var filler:Shape;
		private var _model:VideoJSModel;
		private var isDragging:Boolean;
		
		/**
		 * Constructor
		 * 
		 * @param	backgroundColor fill color behind the volume slider
		 * @param	foregroundColor fill color representing the volume level
		 * @param	width total width of this control
		 */
		public function VideoJSVolume(backgroundColor:uint = 0x666666, foregroundColor:uint = 0xFFFFFF, width:uint = 48) 
		{
			super();
			colorOff = backgroundColor;
			colorOn = foregroundColor;
			currentWidth = width;
			_model = VideoJSModel.getInstance();
			
			var matrix:Matrix = new Matrix();
			matrix.createGradientBox(currentWidth, DEFAULT_HEIGHT, Math.PI / 2);
			graphics.beginGradientFill(GradientType.LINEAR, [0x333333, colorOff], [1, 1], [0, 255], matrix);
			graphics.drawRoundRect(0, 0, currentWidth, DEFAULT_HEIGHT, DEFAULT_HEIGHT);
			graphics.endFill();
			graphics.beginFill(colorOn);
			graphics.drawRoundRect(0, 0, DEFAULT_HEIGHT, DEFAULT_HEIGHT, DEFAULT_HEIGHT);
			graphics.endFill();
			
			filler = new Shape();
			filler.graphics.beginFill(colorOn);
			filler.graphics.drawRect(0, 0, 2, DEFAULT_HEIGHT);
			filler.graphics.endFill();
			filler.x = Math.round(DEFAULT_HEIGHT / 2);
			this.addChild(filler);
			
			icon = new Shape();
			icon.graphics.lineStyle(1, colorOn);
			icon.graphics.beginFill(0xCCCCCC);
			icon.graphics.drawCircle(0, 0, DEFAULT_HEIGHT - 2);
			icon.graphics.endFill();
			icon.y = Math.round(DEFAULT_HEIGHT / 2);
			this.addChild(icon);
			
			this.buttonMode = true;
			this.mouseChildren = false;
			this.addEventListener(MouseEvent.MOUSE_DOWN, startAdjust);
		}
		
		/**
		 * redraw the control based on the model state, and send changes if the user is interacting with it
		 * 
		 * @param	evt timed update
		 */
		internal function update(evt:Event = null):void
		{
			if (isDragging)
			{
				if (stage != null)
				{
					// check range bounds
					var posInPixels:uint = Math.max(0, stage.mouseX - this.x);
					if (posInPixels > currentWidth) posInPixels = currentWidth;
					_model.volume = posInPixels / currentWidth;
				}
			}
			icon.x = Math.round(icon.width / 2 + _model.volume * (currentWidth - icon.width));
			filler.width = Math.max(1, icon.x - filler.x);
		}
		
		/**
		 * when the user clicks on the control, start watching the changes
		 * 
		 * @param	evt typically MOUSE_DOWN input
		 */
		private function startAdjust(evt:MouseEvent = null):void
		{
			isDragging = true;
			if (stage != null)
			{
				stage.addEventListener(MouseEvent.MOUSE_UP, endAdjust);
				update();
			}
		}
		
		/**
		 * stop tracking user input
		 * 
		 * @param	evt typically MOUSE_UP input
		 */
		private function endAdjust(evt:MouseEvent = null):void
		{
			isDragging = false;
			if (stage != null)
			{
				stage.removeEventListener(MouseEvent.MOUSE_UP, endAdjust);
			}
		}
	}

}