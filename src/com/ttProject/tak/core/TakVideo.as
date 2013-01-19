package com.ttProject.tak.core
{
	import com.ttProject.info.Logger;
	
	import flash.media.Video;
	import flash.net.NetStream;
	import com.ttProject.tak.data.BaseStream;

	/**
	 * takStreaming用のvideoオブジェクト
	 * 普通のvideoはサポートしないことにします。
	 */
	public class TakVideo extends Video {
		/**
		 * コンストラクタ
		 */
		public function TakVideo(width:int=320, height:int=240) {
			super(width, height);
		}
		/**
		 * takStream由来のストリームを追加する。
		 */
		public function attachTakStream(takStream:BaseStream):void {
			var ns:NetStream = takStream._ns;
			if(ns == null) {
				var video:TakVideo = this;
				takStream.addEventListener(TakEvent.TAK_EVENT, function(event:TakEvent):void {
					// netStreamが準備できたときにattachを実行する。
					if(event.info.code == "TakEvent.Setup.OK") {
						video.attachNetStream(takStream._ns);
					}
				});
			}
			else {
				attachNetStream(ns);
			}
		}
	}
}