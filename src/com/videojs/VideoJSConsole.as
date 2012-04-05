package com.videojs 
{
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.media.Video;
	import flash.system.System;
	import flash.text.TextField;
	import flash.text.TextFormat;
	
	/**
	 * Visual overlay that can be used for debugging traces.
	 * @author Various
	 */
	public class VideoJSConsole extends Sprite 
	{
		private static var _instance:VideoJSConsole;
		public static const SIZE:uint = 240;
		private static var logs:Vector.<String> = new Vector.<String>();
		
		private var txt:TextField;
		
		/**
		 * Constructor -- consider using the static instance getter instead!
		 */
		public function VideoJSConsole() 
		{
			super();
			
			var style:TextFormat = new TextFormat();
			style.color = 0xFFFFFF;
			style.font = 'arial';
			style.size = 10;
			txt = new TextField();
			txt.defaultTextFormat = style;
			txt.multiline = true;
			//txt.selectable = true;
			txt.wordWrap = true;
			txt.width = SIZE * 1.5;
			txt.height = SIZE;
			txt.text = "Console Initiated.";
			this.addChild(txt);
			
			this.graphics.beginFill(0x333333, 0.5);
			this.graphics.drawRect(0, 0, txt.width, txt.height);
			this.graphics.endFill();
			
			this.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown, false, 0, true);
		}
		
		/**
		 * make it easy to copy the text by clicking on it
		 * 
		 * @param	evt mouse down
		 */
		private function onMouseDown(evt:MouseEvent = null):void 
		{
			System.setClipboard(fullText);
		}
		
		private function refresh():void
		{
			//if (txt.stage == null) return;
			txt.text = text;
			txt.scrollV = txt.maxScrollV;
		}
		
		/**
		 * Writes a new line of text to the console
		 * 
		 * @param message A new line of text to write to the console
		 */
		public static function log(message:String = ""):void
		{
			trace("log: " + message);
			logs.push(message);
			instance.refresh();
		}
		
		/**
		 * get the last 50 posts to the console
		 */
		private static function get text():String
		{
			var result:String = "";
			// just get the last 50 posts (should be sufficient)
			var N:int = logs.length;
			var start:int = N - 50;
			if (start < 0) start = 0;
			for (var i:int = start; i < N; i++) result += "\n" + logs[i];
			return result;
		}
		
		/**
		 * get all the console logs as a single string
		 */
		public static function get fullText():String
		{
			var result:String = "";
			var N:int = logs.length;
			for (var i:int = 0; i < N; i++) result += "\n" + logs[i];
			return result;
		}
		
		/**
		 * singleton-like static accessor
		 */
		public static function get instance():VideoJSConsole
		{
			if (_instance == null) _instance = new VideoJSConsole();
			return _instance;
		}
		
	}

}