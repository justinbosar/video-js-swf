package com.videojs.structs{
    
    public class PlaybackType{
        
		/**
		 * normal HTTP media server
		 */
        public static const HTTP:String = "PlaybackType.HTTP";
		
		/**
		 * HTTP media server that supports sub-clip requests using the "ms=X" query parameter (eg, LimeLight)
		 */
        public static const HTTP_PARTIAL:String = "PlaybackType.HTTP_PARTIAL";
		
		/**
		 * Adobe/Macromedia streaming server
		 */
        public static const RTMP:String = "PlaybackType.RTMP";
        
    }
}