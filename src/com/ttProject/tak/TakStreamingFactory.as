package com.ttProject.tak
{
	import com.ttProject.info.Logger;
	import com.ttProject.tak.core.TakStream;
	import com.ttProject.tak.core.TakVideo;
	import com.ttProject.tak.http.HttpTakStream;
	import com.ttProject.tak.rtmp.RtmpTakStream;
	
	import flash.display.Sprite;
	import flash.media.Video;
	import flash.net.NetStream;

	/**
	 * takStreamingのストリーム作成ファクトリー
	 */
	public class TakStreamingFactory extends Sprite {
		private static var stream:TakStream;
		private static var video:TakVideo = new TakVideo();
		/**
		 * ストリームを取得する
		 */
		public static function getStream(url:String):NetStream {
			// 指定したタイプのtakStreamをつくって応答します
			if(stream != null) {
				stream.close();
				stream = null;
			}
			Logger.info(url);
			switch(url.split(":")[0]) {
				case "http":
					Logger.info("http");
					// すでに前につくったのがあったら止めた方がよいということか。
					stream = new HttpTakStream(url);
					break;
				case "rtmp":
					Logger.info("rtmp");
					stream = new RtmpTakStream(url);
					break;
				case "rtmfp":
					Logger.info("rtmfp");
					break;
				default:
					Logger.info("unknown");
					break;
			}
			if(video != null) {
				video.attachTakStream(stream);
			}
			return stream;
		}
		/**
		 * videoを取得する。
		 */
		public static function getVideo(width:int=320, height:int=240):TakVideo {
			video.width = width;
			video.height = height;
			if(stream != null) {
				video.attachTakStream(stream);
			}
			return video;
		}
	}
}