package com.videojs.gui 
{
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.text.StyleSheet;
	
	/**
	 * Collection of settings that determine GUI appearance.  Can include a CSS file.
	 * @author Justin Bosar
	 */
	public class VideoJSTheme extends EventDispatcher 
	{
		private static var _instance:VideoJSTheme;
		private var css:StyleSheet;
		
		/**
		 * Constructor
		 * 
		 * @param	cssURL
		 * @param	callback
		 */
		public function VideoJSTheme(cssURL:String = "", callback:Function = null) 
		{
			super();
			_instance = this;
		}
		
		/**
		 * color at the top of the gradient behind the seek bar
		 */
		public function get colorBgSeekTop():uint
		{
			if (css != null)
			{
				return 0x222222;
			}
			else return 0x222222;
		}
		
		/**
		 * color at the bottom of the gradient behind the seek bar
		 */
		public function get colorBgSeekBottom():uint
		{
			if (css != null)
			{
				return 0x333333;
			}
			else return 0x333333;
		}
		
		/**
		 * color at the top of the gradient behind the seek bar
		 */
		public function get colorBgBorderTop():uint
		{
			if (css != null)
			{
				return 0x1E1E1E;
			}
			else return 0x1E1E1E;
		}
		
		/**
		 * color at the bottom of the gradient behind the seek bar
		 */
		public function get colorBgBorderBottom():uint
		{
			if (css != null)
			{
				return 0x404040;
			}
			else return 0x404040;
		}
		
		public static function get instance():VideoJSTheme
		{
			if (_instance == null) _instance = new VideoJSTheme();
			return _instance;
		}
		
	}

}