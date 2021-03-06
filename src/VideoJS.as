package{
    
	import com.videojs.gui.VideoJSGUI;
    import com.videojs.VideoJSApp;
	import com.videojs.VideoJSConsole;
    import com.videojs.VideoJSModel;
    import com.videojs.VideoJSView;
    import com.videojs.events.VideoJSEvent;
    import com.videojs.structs.ExternalErrorEventName;
	import flash.events.ContextMenuEvent;
	import flash.events.KeyboardEvent;
    
    import flash.display.Sprite;
    import flash.display.StageAlign;
    import flash.display.StageScaleMode;
    import flash.events.Event;
    import flash.events.IEventDispatcher;
    import flash.events.TimerEvent;
    import flash.external.ExternalInterface;
    import flash.geom.Rectangle;
    import flash.media.Video;
    import flash.system.Security;
    import flash.ui.ContextMenu;
    import flash.ui.ContextMenuItem;
    import flash.utils.Timer;
    import flash.utils.setTimeout;
    
    [SWF(backgroundColor="#000000", frameRate="60", width="480", height="270")]
    public class VideoJS extends Sprite{
        
		/**
		 * disable to build without console...recommend FALSE for all production deploys because the console eats cycles that should be spent decoding
		 */
		public static const ALLOW_CONSOLE:Boolean = true;
		
		/**
		 * In order to use HTTPPartialVideoProvider instead of HTTPVideoProvider, set this to true (from flashVars.allowPartial)
		 */
		public static var allowPartial:Boolean = false;
		
		/**
		 * if true, we need to redirect to a new URL when the user clicks on the video itself
		 */
		public static var isClickThrough:Boolean = false;
		
		/**
		 * URL to send the user to when they click on the video (not used if isClickThrough is false)
		 */
		public static var destURL:String = "";
		
		/**
		 * show/hide GUI option
		 */
		public static var showControls:Boolean = false;
		
		/**
		 * if we're in an environment where JavaScript performance is poor (IE7/IE8), set this to true to force a fallback GUI
		 */
		public static var useFlashUI:Boolean = false;
		// WIP
		
		/**
		 * If true, and using HTTPPartialVideoProvider, save the path if it appears to have been redirected on the initial stream request (can be set from flashVars.allowCachedRedirect)
		 */
		public static var allowCachedRedirect:Boolean = false;
		// still a WIP,  doesn't do anything useful yet
		
        private var _app:VideoJSApp;
        private var _stageSizeTimer:Timer;
        
        public function VideoJS(){
            _stageSizeTimer = new Timer(250);
            _stageSizeTimer.addEventListener(TimerEvent.TIMER, onStageSizeTimerTick);
            addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
			
			// if the player starts out paused and not buffering, JS was trying to poll "buffered" but there were no accessors yet
			// this silences the error and returns 0 until things are truly ready
			if (ExternalInterface.available)
			{
                ExternalInterface.addCallback("vjs_getProperty", temporaryCallback);
			}
			else
			{
				if (ALLOW_CONSOLE) VideoJSConsole.log('VideoJS constructor was unable to detect ExternalInterface');
			}
        }
		
		/**
		 * this can catch some calls from JavaScript temporarily, until the Flash player is properly initialized
		 * 
		 * @param	pPropertyName
		 * @return  always 0
		 */
		public function temporaryCallback(pPropertyName:String = ""):*
		{
			if (ALLOW_CONSOLE) VideoJSConsole.log('temporaryCallback: ' + pPropertyName);
			return 0;
		}
		
        private function init():void {
			if (ALLOW_CONSOLE) VideoJSConsole.log('VideoJS.init()');
            // Allow JS calls from other domains
            Security.allowDomain("*");
            Security.allowInsecureDomain("*");

            if(loaderInfo.hasOwnProperty("uncaughtErrorEvents")){
                // we'll want to suppress ANY uncaught debug errors in production (for the sake of ux)
                // IEventDispatcher(loaderInfo["uncaughtErrorEvents"]).addEventListener("uncaughtError", onUncaughtError);
            }
            
            if(ExternalInterface.available){
                registerExternalMethods();
            }
            
            _app = new VideoJSApp();
            addChild(_app);
			
			// watch for console hotkey (tilde if allowed)
			if (ALLOW_CONSOLE) 
			{
				if (stage != null) stage.focus = this;
				this.addEventListener(KeyboardEvent.KEY_UP, watchKeys, false, 0, false);
				this.addEventListener(Event.ENTER_FRAME, keepFocusOnFrame, false, 0, true);
			}
			
            _app.model.stageRect = new Rectangle(0, 0, stage.stageWidth, stage.stageHeight);
			
            // add content-menu version info
            var _ctxVersion:ContextMenuItem = new ContextMenuItem("VideoJS Flash Component v3.0.1c", false, false);
            var _ctxAbout:ContextMenuItem = new ContextMenuItem("Copyright © 2012 Zencoder, Inc.", false, false);
			
			// TODO add context controls similar to HTML5 version - currently, no MENU_ITEM_SELECT event fires, possibly due to JS GUI interference?
			/*
			var _ctxPlay:ContextMenuItem = new ContextMenuItem("Play/Pause", true);
			_ctxPlay.addEventListener(ContextMenuEvent.MENU_ITEM_SELECT, togglePlayFromContext);
			var _ctxMute:ContextMenuItem = new ContextMenuItem("Mute");
			*/
			
            var _ctxMenu:ContextMenu = new ContextMenu();
            _ctxMenu.hideBuiltInItems();
            _ctxMenu.customItems.push(_ctxVersion, _ctxAbout);
            this.contextMenu = _ctxMenu;
        }
		
		/**
		 * allow play-pause functionality from the Flash context menu (similar to right clicking on HTML5)
		 * 
		 * @param	evt click on a menu item
		 */
		private function togglePlayFromContext(evt:ContextMenuEvent):void
		{
			// the context menu isn't done...
			if (ALLOW_CONSOLE) VideoJSConsole.log('togglePlayFromContext(): ' + evt);
			if (evt != null)
			{
				if (_app != null)
				{
					if (_app.model.paused) _app.model.play();
					else _app.model.pause();
				}
			}
		}
        
        private function registerExternalMethods():void{
            
            try{
                ExternalInterface.addCallback("vjs_echo", onEchoCalled);
                ExternalInterface.addCallback("vjs_getProperty", onGetPropertyCalled);
                ExternalInterface.addCallback("vjs_setProperty", onSetPropertyCalled);
                ExternalInterface.addCallback("vjs_autoplay", onAutoplayCalled);
                ExternalInterface.addCallback("vjs_src", onSrcCalled);
                ExternalInterface.addCallback("vjs_load", onLoadCalled);
                ExternalInterface.addCallback("vjs_play", onPlayCalled);
                ExternalInterface.addCallback("vjs_pause", onPauseCalled);
                ExternalInterface.addCallback("vjs_resume", onResumeCalled);
                ExternalInterface.addCallback("vjs_stop", onStopCalled);
				ExternalInterface.addCallback("vjs_fullscreen", onFullscreenCalled);
            }
            catch(e:SecurityError){
                if (loaderInfo.parameters.debug != undefined && loaderInfo.parameters.debug == "true") {
                    throw new SecurityError(e.message);
                }
            }
            catch(e:Error){
                if (loaderInfo.parameters.debug != undefined && loaderInfo.parameters.debug == "true") {
                    throw new Error(e.message);
                }
            }
            finally{}
            
            
            
            setTimeout(finish, 50);

        }
        
        private function finish():void{
			if (ALLOW_CONSOLE) VideoJSConsole.log('VideoJS.finish()');
            if(loaderInfo.parameters.mode != undefined){
                _app.model.mode = loaderInfo.parameters.mode;
            }
            
            if(loaderInfo.parameters.eventProxyFunction != undefined){
                _app.model.jsEventProxyName = loaderInfo.parameters.eventProxyFunction;
            }
            
            if(loaderInfo.parameters.errorEventProxyFunction != undefined){
                _app.model.jsErrorEventProxyName = loaderInfo.parameters.errorEventProxyFunction;
            }
            
            if(loaderInfo.parameters.autoplay != undefined && loaderInfo.parameters.autoplay == "true"){
                _app.model.autoplay = true;
            }
            
            if(loaderInfo.parameters.preload != undefined && loaderInfo.parameters.preload == "true"){
                _app.model.preload = true;
            }
			
			if (loaderInfo.parameters.allowPartial != undefined && loaderInfo.parameters.allowPartial == "true") {
				allowPartial = true;
			}
            
			if (loaderInfo.parameters.isClickThrough != undefined && loaderInfo.parameters.isClickThrough == "true") {
				isClickThrough = true;
			}
            
			if (loaderInfo.parameters.destURL != undefined) {
				destURL = loaderInfo.parameters.destURL;
			}
			
			if (loaderInfo.parameters.controls != undefined && loaderInfo.parameters.controls == "true") {
				showControls = true;
			}
            
			if (loaderInfo.parameters.flashUI != undefined && loaderInfo.parameters.flashUI == "true") {
				useFlashUI = true;
			}
			
			if (loaderInfo.parameters.logoURL != undefined) {
				VideoJSGUI.logoURL = loaderInfo.parameters.logoURL;
			}
			
			// sadly, this ain't ready for primetime - Adobe makes it too hard to get HTTP reponse headers in the name of security
			//if (loaderInfo.parameters.allowCachedRedirect != undefined && loaderInfo.parameters.allowCachedRedirect == "true") {
			//	allowCachedRedirect = true;
			//}
            
            if (loaderInfo.parameters.poster != undefined && loaderInfo.parameters.poster != "") {
                _app.model.poster = String(loaderInfo.parameters.poster);
            }
            
            if(loaderInfo.parameters.src != undefined && loaderInfo.parameters.src != ""){
				if (ALLOW_CONSOLE) VideoJSConsole.log('VideoJS.finish() -> parameters.src = ' + loaderInfo.parameters.src);
                _app.model.srcFromFlashvars = String(loaderInfo.parameters.src);
            }
            else{
                if(loaderInfo.parameters.RTMPConnection != undefined && loaderInfo.parameters.RTMPConnection != ""){
                    _app.model.rtmpConnectionURL = loaderInfo.parameters.RTMPConnection;
                }
                if(loaderInfo.parameters.RTMPStream != undefined && loaderInfo.parameters.RTMPStream != ""){
                    _app.model.rtmpStream = loaderInfo.parameters.rtmpStream;
                }
            }
            
            if(loaderInfo.parameters.readyFunction != undefined){
                try{
                    ExternalInterface.call(loaderInfo.parameters.readyFunction, ExternalInterface.objectID);
                }
                catch(e:Error){
                    if (loaderInfo.parameters.debug != undefined && loaderInfo.parameters.debug == "true") {
                        throw new Error(e.message);
                    }
                }
            }
        }
        
        private function onAddedToStage(e:Event):void {
            stage.addEventListener(Event.RESIZE, onStageResize);
            stage.scaleMode = StageScaleMode.NO_SCALE;
            stage.align = StageAlign.TOP_LEFT;
            _stageSizeTimer.start();
        }
		
		/**
		 * if the console is allowed, try to keep the keyboard focus.  this is pretty brute-force so set ALLOW_CONSOLE to false for production!!!
		 * 
		 * @param	evt check on frame
		 */
		private function keepFocusOnFrame(evt:Event = null):void
		{
			if (stage != null) stage.focus = this;
		}
		
		private function watchKeys(evt:KeyboardEvent):void
		{
			switch (evt.keyCode) 
			{
				case 192: // `~ to toggle on screen trace console
					if (!this.contains(VideoJSConsole.instance)) this.addChild(VideoJSConsole.instance);
					else this.removeChild(VideoJSConsole.instance);
					break;
				default:
					break;
			}
		}
        
        private function onStageSizeTimerTick(e:TimerEvent):void {
            if(stage.stageWidth > 0 && stage.stageHeight > 0){
                _stageSizeTimer.stop();
                _stageSizeTimer.removeEventListener(TimerEvent.TIMER, onStageSizeTimerTick);
                init();
				
            }
        }
        
        private function onStageResize(e:Event):void {
            if(_app != null){
                _app.model.stageRect = new Rectangle(0, 0, stage.stageWidth, stage.stageHeight);
                _app.model.broadcastEvent(new VideoJSEvent(VideoJSEvent.STAGE_RESIZE, {}));
            }
        }
        
        private function onEchoCalled(pResponse:* = null):*{
            return pResponse;
        }
        
        private function onGetPropertyCalled(pPropertyName:String = ""):*{
			if (_app == null)
			{
				if (ALLOW_CONSOLE) VideoJSConsole.log('ERROR: onGetPropertyCalled() but app is null.');
				return 0;
			}
			if (_app.model == null) 
			{
				if (ALLOW_CONSOLE) VideoJSConsole.log('ERROR: onGetPropertyCalled() but model is null.');
				return 0;
			}
			
			// originally, first 3 cases were missing a break...was that intentional?  probably not a problem because of return statements, but otherwise would cause fall through
			switch(pPropertyName){
                case "mode":
                    return _app.model.mode;
					break;
                case "autoplay":
                    return _app.model.autoplay;
					break;
                case "loop":
                    return _app.model.loop;
					break;
                case "preload":
                    return _app.model.preload;    
                    break;
                case "metadata":
                    return _app.model.metadata;
                    break;
                case "duration":
                    return _app.model.duration;
                    break;
                case "eventProxyFunction":
                    return _app.model.jsEventProxyName;
                    break;
                case "errorEventProxyFunction":
                    return _app.model.jsErrorEventProxyName;
                    break;
                case "currentSrc":
                    return _app.model.src;
                    break;
                case "currentTime":
                    return _app.model.time;
                    break;
                case "time":
                    return _app.model.time;
                    break;
                case "initialTime":
                    return 0;
                    break;
                case "defaultPlaybackRate":
                    return 1;
                    break;
                case "ended":
                    return _app.model.hasEnded;
                    break;
                case "volume":
                    return _app.model.volume;
                    break;
                case "muted":
                    return _app.model.muted;
                    break;
                case "paused":
                    return _app.model.paused;
                    break;
                case "seeking":
                    return _app.model.seeking;
                    break;
                case "networkState":
                    return _app.model.networkState;
                    break;
                case "readyState":
                    return _app.model.readyState;
                    break;
                case "buffered":
                    return _app.model.buffered;
                    break;
                case "bufferedBytesStart":
                    return 0; // TODO we could report a more accurate value here if we're using a sub-clip
                    break;
                case "bufferedBytesEnd":
                    return _app.model.bufferedBytesEnd;
                    break;
                case "bytesTotal":
                    return _app.model.bytesTotal;
                    break;
                case "videoWidth":
                    return _app.model.videoWidth;
                    break;
                case "videoHeight":
                    return _app.model.videoHeight;
                    break;
            }
            return null;
        }
        
        private function onSetPropertyCalled(pPropertyName:String = "", pValue:* = null):void{
			if (ALLOW_CONSOLE) VideoJSConsole.log('VideoJS.onSetPropertyCalled(): ' + pPropertyName + " : " + pValue);
            switch(pPropertyName){
                case "mode":
                    _app.model.mode = String(pValue);
                    break;
                case "loop":
                    _app.model.loop = _app.model.humanToBoolean(pValue);
                    break;
                case "background":
                    _app.model.backgroundColor = _app.model.hexToNumber(String(pValue));
                    break;
                case "eventProxyFunction":
                    _app.model.jsEventProxyName = String(pValue);
                    break;
                case "errorEventProxyFunction":
                    _app.model.jsErrorEventProxyName = String(pValue);
                    break;
                case "preload":
                    _app.model.preload = _app.model.humanToBoolean(pValue);
                    break;
                case "poster":
                    _app.model.poster = String(pValue);
                    break;
                case "src":
                    _app.model.src = String(pValue);
                    break;
                case "currentTime":
                    _app.model.seekBySeconds(Number(pValue));
                    break;
                case "currentPercent":
                    _app.model.seekByPercent(Number(pValue));
                    break;
                case "muted":
                    _app.model.muted = _app.model.humanToBoolean(pValue);
                    break;
                case "volume":
                    _app.model.volume = Number(pValue);
                    break;
                case "RTMPConnection":
                    _app.model.rtmpConnectionURL = String(pValue);
                    break;
                case "RTMPStream":
                    _app.model.rtmpStream = String(pValue);
                    break;
                default:
                    _app.model.broadcastErrorEventExternally(ExternalErrorEventName.PROPERTY_NOT_FOUND, pPropertyName);
                    break;
            }
        }
        
        private function onAutoplayCalled(pAutoplay:* = false):void{
            _app.model.autoplay = _app.model.humanToBoolean(pAutoplay);
        }
        
        private function onSrcCalled(pSrc:* = ""):void{
            _app.model.src = String(pSrc);
        }
        
        private function onLoadCalled():void{
            _app.model.load();
        }
        
        private function onPlayCalled():void{
            _app.model.play();
        }
        
        private function onPauseCalled():void {
			if (ALLOW_CONSOLE) VideoJSConsole.log('onPauseCalled()');
            _app.model.pause();
        }
        
        private function onResumeCalled():void{
            _app.model.resume();
        }
        
        private function onStopCalled():void{
            _app.model.stop();
        }
		
		private function onFullscreenCalled():void
		{
			VideoJSGUI.onToggleFullscreen(!VideoJSGUI.isFullscreen);
		}
        
        private function onUncaughtError(e:Event):void{
            e.preventDefault();
        }
        
    }
}
