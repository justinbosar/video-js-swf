package com.videojs.providers{
    
	import com.videojs.VideoJSConsole;
    import com.videojs.VideoJSModel;
    import com.videojs.events.VideoPlaybackEvent;
    import com.videojs.structs.ExternalEventName;
    
	/**
	 * Modified HTTPVideoProvider which supports the sub-clip feature supported by some CDNs (like LimeLight).
	 * This feature is intended to make skipping far ahead in long videos much faster for users.
	 * When you seek outside what is buffered, it requests a new stream and stops trying to buffer
	 * all the content which you have skipped.  YouTube utilizes a similar feature.  
	 * One negative side effect: when you skip ahead into a sub-clip, everything preceeding the seek
	 * location becomes unbuffered (effectively, outside the scope of the stream).  Therefore,
	 * jumping back to the beginning also clears the buffer and requests a new stream.
	 * Again, YouTube exhibits this same behavior.
	 * 
	 * This class includes a few modified get functions for things like duration.  This is because
	 * we must hide the fact that we are using a sub-clip from the GUI, which is outside Flash.
	 * The Model knows to call these modified getters when this class is used as the Provider.
	 * The original getters from the superclass must remain intact for playback to function properly.
	 * 
	 * Currently this class assumes the server implementation uses a query parameter "ms=X"
	 * to request as sub-clip.  This is known to work for LimeLight, but other CDNs are untested!!!
	 * Modify "seekBySeconds()" to add support for other implementations.
	 * 
	 * @author Various
	 */
    public class HTTPPartialVideoProvider extends HTTPVideoProvider implements IProvider{
        
		/**
		 * When you attempt to skip ahead to an unbuffered point, special behaviors may be required
		 */
		private var _isStreaming:Boolean = false;
		
		/**
		 * If the stream has been re-fetched with an "ms" parameter (offset buffer / sub-clip) we'll need to save that value
		 */
		private var _previousStreamingOffset:Number = 0;
		
		/**
		 * cache the first duration metadata encountered, in case we want to hide subsequent changes from the external seek logic.
		 */
		private var _originalDuration:int = -1;
		
		/**
		 * If specified by VideoJS.allowCachedRedirect, the result of the originial stream request is saved for future sub-clip requests
		 */
		private var _cachedRedirectURL:String = "";
        
        public function HTTPPartialVideoProvider() {
			super();
        }

        override public function init(pSrc:Object, pAutoplay:Boolean):void{
            _src = pSrc;
			if (VideoJS.allowCachedRedirect) _cachedRedirectURL = _src.path; 
            _loadErrored = false;
            _loadStarted = false;
            _loadCompleted = false;
            if(pAutoplay) initNetConnection();
        }
		/**
		 * the model may need a modified time if we've skipped to an unbuffered section (which changes the metadata duration)
		 */
        public function get timeForModel():Number{
            if (_ns != null) {
				// shouldn't return more than the duration, though it's possible somehow (probably because of rounding back to the nearest MPEG-4 keyframe on seeks)
				if (VideoJS.ALLOW_CONSOLE) VideoJSConsole.log('HTTPPartialVideoProvider -> get timeForModel: ' + String(_pausedSeekValue) + ', ' + String(_ns.time + _previousStreamingOffset));
                if(_pausedSeekValue != -1){
                    return Math.min(_pausedSeekValue, durationForModel);
                }
                else{
                    return Math.min(_ns.time + _previousStreamingOffset, durationForModel);
                }
            }
            else{
                return 0;
            }
        }
		
		/**
		 * the model may need a modified duration if we've skipped to an unbuffered section (which changes the metadata duration)
		 */
        public function get durationForModel():Number {
			//if (VideoJS.ALLOW_CONSOLE) VideoJSConsole.log('HTTPVideoProvider -> get durationForModel: ' + _isStreaming + ', ' + _originalDuration + ', ' + _metadata.duration);
            if (_metadata != null && _metadata.duration != undefined) {
				if (_isStreaming) {
					return Number(_originalDuration);
				}
				else {
					return Number(_metadata.duration);
				}
            }
            else{
                return 0;
            }
        }
		
		/**
		 * the model may need a modified state if we've skipped to an unbuffered section (which changes the metadata duration)
		 */
        public function get bufferedForModel():Number{
            if (duration > 0) {
				if (VideoJS.ALLOW_CONSOLE) VideoJSConsole.log('HTTPPartialVideoProvider -> get bufferedForModel: ' + String((_ns.bytesLoaded / _ns.bytesTotal) * duration + _previousStreamingOffset));
				// make sure previous out-of-buffer seeks haven't caused buffer to be greater than duration
                return Math.min((_ns.bytesLoaded / _ns.bytesTotal) * duration + _previousStreamingOffset, durationForModel);
            }
            else{
                return 0;
            }
        }
		
		/**
		 * request a subclip from a server that supports the "ms" offset parameter
		 * 
		 * @param	time new beginning of the stream in seconds
		 */
		private function seekNewSubClip(time:Number = 0):void
		{
			_isStreaming = true;
			_previousStreamingOffset = time;
			// if we're in sub-clip land, perhaps reporting stream events (such as new metadata) to the container isn't desirable.
			// in practice, the JS GUI doesn't seem to rely on these events, it's always polling accessors anyway
			//VideoJSModel.isSilent = true;
			var cmd:String = _src.path + '?ms=' + time;
			if (VideoJS.ALLOW_CONSOLE) VideoJSConsole.log('--> trying buffer offset: ' + cmd);
			_ns.play(cmd);
		}
		
		/**
		 * Move the playback "head".  This version will request a sub-clip from the server if you seek outside of what's buffered.
		 * 
		 * @param	pTime number of seconds into the clip that playback will resume from
		 */
        override public function seekBySeconds(pTime:Number):void {
			if (VideoJS.ALLOW_CONSOLE) VideoJSConsole.log('HTTPPartialVideoProvider.seekBySeconds(): ' + pTime + ' - ' + _previousStreamingOffset + ' buffer: ' + buffered);
			// TODO can this function be simplified?
			var modifiedTime:Number = pTime;
			// if we've used the streaming offset feature on this media before, then all future seeks need to be checked...
			if (_previousStreamingOffset > 0)
			{
				// the stream is actually a sub-clip now (probably containing a range from the offset to the end, but nothing before the offset)
				
				// if we're going forward in the current sub-clip...
				if (pTime > _previousStreamingOffset) modifiedTime -= _previousStreamingOffset;
				
				// if we're going back to a time before the current sub-clip...
				if (pTime < _previousStreamingOffset) modifiedTime -= _previousStreamingOffset; // this should end up negative!
			}
			
            if(_isPlaying){
                if(duration != 0 && modifiedTime <= duration){
					if (VideoJS.ALLOW_CONSOLE) VideoJSConsole.log('--> modifiedTime, duration: ' + modifiedTime + ', ' + duration);
                    _isSeeking = true;
					//_isStreaming = false;
                    _throughputTimer.stop();
                    if(_isPaused){
						_pausedSeekValue = pTime;
                    }
					// if the video source supports buffer offset and you're moving outside the current buffer, get a subclip (should be faster)
                    if ((modifiedTime > buffered) || (modifiedTime < 0)) {
						seekNewSubClip(pTime);
					}
                    else {
						_ns.seek(modifiedTime);
					}
                    _isBuffering = true;
                }
            }
            else if (_hasEnded) {
				if (modifiedTime < 0)
				{
					_isSeeking = true;
                    _throughputTimer.stop();
                    if(_isPaused){
                        _pausedSeekValue = pTime; 
                    }
					seekNewSubClip(pTime);
				}
                else 
				{
					_ns.seek(modifiedTime);
					_isStreaming = false;
				}
                _isPlaying = true;
                _hasEnded = false;
                _isBuffering = true;
            }
        }
        
		/**
		 * Read new media variables.  This version may suppress external events if we suspect the new metadata comes from a sub-clip.
		 * 
		 * @param	pMetaData video clip metadata
		 */
        override public function onMetaData(pMetaData:Object):void{
			if (VideoJS.ALLOW_CONSOLE) VideoJSConsole.log('HTTPPartialVideoProvider.onMetaData(): ' + String(pMetaData.duration));
            _metadata = pMetaData;
            if(pMetaData.duration != undefined){
                _isLive = false;
                _canSeekAhead = true;
				if (_originalDuration == -1) 
				{
					// when "skipping ahead" beyond what's buffered (eg, using the "ms" query parameter on LimeLight)
					// the stream length effectively changes...but reporting this new duration to the JS GUI is undesirable
					_originalDuration = pMetaData.duration;
					_model.broadcastEventExternally(ExternalEventName.ON_DURATION_CHANGE, _metadata.duration);
					// upon further testing, JS seems to do little or nothing with this event...instead, it polls the duration accessor CONSTANTLY;
					// that may be impacting performance somewhat, since get functions in Flash incur some object creation overhead
				}
            }
            else{
                _isLive = true;
                _canSeekAhead = false;
            }
            _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_META_DATA, {metadata:_metadata}));
            if (!_metadata.duration) _model.broadcastEventExternally(ExternalEventName.ON_METADATA, _metadata);
        }
    }
}