package com.ttProject.tak
{
	import com.ttProject.tak.core.TakStream;
	import com.ttProject.tak.core.TakVideo;
	
	import flash.display.Sprite;
	import flash.media.Video;
	import flash.net.NetStream;

	/**
	 * flashのプログラマが一般的に扱うFactory動作のクラス
	 * 
	 * とりあえずネットワーク追加はあるけど、削除とリスト参照は未実装
	 */
	public class TakStreamingFactory extends Sprite
	{
		// 複数データを保持できるようにしておく。
		private static var list:Object = {};
		/**
		 * ストリームを取得
		 */
		public static function getStream(key:String = null):NetStream {
			return getData(key).stream;
		}
		/**
		 * ビデオを取得
		 */
		public static function getVideo(key:String = null):Video {
			return getData(key).video;
		}
		/**
		 * ダウンロード元を追加
		 */
		public static function addSource(url:String, name:String, key:String = null):void {
			getData(key).stream.addSource(url, name);
		}
		/**
		 * 提供先を設定
		 */
		public static function setSupply(url:String, name:String, key:String = null):void {
			getData(key).stream.setSupply(url, name);
		}
		/**
		 * 内部処理補助
		 */
		private static function getData(key:String):TakObjects {
			if(list[key] == null) {
				var objects:TakObjects = new TakObjects();
				list[key] = objects;
			}
			return list[key] as TakObjects;
		}
		/**
		 * 動作ロガーを追加
		 * クラスオブジェクトでerror warn info debugの各メソッド(引数はstring)を持つものを対象に動作します。
		 */
		public static function setLogger(logger:*):void {
			Logger.setLogger(logger);
		}
	}
}

import com.ttProject.tak.core.TakStream;
import com.ttProject.tak.core.TakVideo;

/**
 * takStreamで利用するオブジェクトホルダー
 */
class TakObjects {
	private var _stream:TakStream;
	private var _video:TakVideo;
	public function TakObjects() {
		_stream = new TakStream();
		_video = new TakVideo();
		_video.attachTakStream(_stream); // 始めからvideoとstreamは連携させておく。
	}
	public function get stream():TakStream {
		return _stream;
	}
	public function get video():TakVideo {
		return _video;
	}
}