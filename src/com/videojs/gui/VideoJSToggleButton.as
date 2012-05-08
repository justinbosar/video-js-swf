package com.videojs.gui 
{
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	
	/**
	 * 2-state button for use with the fallback Flash GUI
	 * @author Justin Bosar
	 */
	public class VideoJSToggleButton extends Sprite 
	{
		private var primary:DisplayObject;
		private var secondary:DisplayObject;
		private var myState:Boolean;
		private var handler:Function;
		private var hitShape:Shape;
		
		/**
		 * Constructor -
		 * 
		 * @param	artPrimary art used in the button's intitial (false) state
		 * @param	artSecondary art used in the buttons's clicked (true) state
		 * @param	callback function called when the button is clicked.  function will receive the new state as a Boolean.
		 */
		public function VideoJSToggleButton(artPrimary:DisplayObject, artSecondary:DisplayObject, callback:Function = null) 
		{
			super();
			primary = artPrimary;
			secondary = artSecondary;
			handler = callback;
			myState = false;
			this.addChild(artPrimary);
			
			hitShape = new Shape();
			hitShape.graphics.beginFill(0x000000, 0);
			hitShape.graphics.drawRect(0, 0, artPrimary.width, artPrimary.height);
			hitShape.graphics.endFill();
			this.addChildAt(hitShape, 0);
			
			this.addEventListener(MouseEvent.CLICK, toggle);
			this.buttonMode = true;
		}
		
		/**
		 * get the current state of the toggle button.  the initial state is false.  
		 */
		public function get state():Boolean
		{
			return myState;
		}
		
		/**
		 * force the state to true or false (without triggering the callback)
		 * 
		 * @param	target new state
		 */
		public function force(target:Boolean):void
		{
			if (myState != target)
			{
				toggle();
			}
		}
		
		/**
		 * flip the button state as if clicked, calling the handler function (if one exists and this toggle was user-initiated)
		 * 
		 * @param	evt usually a mouse click but it can be omitted
		 * @return the new state
		 */
		public function toggle(evt:MouseEvent = null):Boolean
		{
			if (evt != null) evt.stopImmediatePropagation();
			if (myState)
			{
				myState = false;
				if (this.contains(secondary)) this.removeChild(secondary);
				if (!this.contains(primary)) this.addChild(primary);
			}
			else
			{
				myState = true;
				if (this.contains(primary)) this.removeChild(primary);
				if (!this.contains(secondary)) this.addChild(secondary);
			}
			
			if ((handler != null) && (evt != null)) handler(myState);
			return myState;
		}
		
	}

}