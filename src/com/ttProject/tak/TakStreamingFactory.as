package com.ttProject.tak
{
	import com.ttProject.info.Logger;
	import com.ttProject.tak.core.TakStream;
	import com.ttProject.tak.core.TakVideo;
	import com.ttProject.tak.http.HttpTakStream;
	import com.ttProject.tak.multi.MultiTakStream;
	
	import flash.media.Video;
	import flash.net.NetStream;

	public class TakStreamingFactory
	{
		private static var stream:TakStream;
		private static var video:TakVideo = new TakVideo();
		
		/**
		 * 応答するnetStreamは１つだが、中身はいくつかのハイブリッドになっているものとする。
		 */
		public static function getStream(origin:String, name:String, p2pNetwork:String="", subP2pNetwork:String=""):NetStream {
			if(stream != null) {
				stream.close();
				stream = null;
			}
			Logger.info(origin);
			switch(origin.split(":")[0]) {
				case "http":
					Logger.info("http");
					stream = new HttpTakStream(origin, name, p2pNetwork, subP2pNetwork);
					break;
				case "rtmp":
					Logger.info("rtmp");
					break;
				default:
					Logger.info("no specify for origin");
					break;
			}
			return stream;
		}
		public static function getVideo(width:int=320, height:int=240):Video {
			video.width  = width;
			video.height = height;
			if(stream != null) {
				video.attachTakStream(stream);
			}
			return video;
		}
	}
}