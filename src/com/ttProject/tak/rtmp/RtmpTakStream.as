package com.ttProject.tak.rtmp
{
	import com.ttProject.info.Logger;
	import com.ttProject.tak.core.TakStream;
	
	import flash.events.NetStatusEvent;
	import flash.net.Responder;
	import flash.utils.ByteArray;
	
	/**
	 * rtmpの接続はrtmpサーバーに接続してデータをダウンロードしていきます。
	 * 
	 * 下記の補完動作はまだつくってない。
	 * dlに失敗した場合はrtmpで補完できるか確認して、できるならそこでやり直す。
	 * httpで補完可能な場合はそちらでもやり直す。
	 */
	public class RtmpTakStream extends TakStream {
		private var _tc:TakConnection;
		// ターゲットとする名前
		private var name:String = null;
		// 初期化フラグ
		private var initialized:Boolean = false;
		// 再生要求送信フラグ
		private var requestDataInvoked:Boolean = false;
		/**
		 * コンストラクタ
		 */
		public function RtmpTakStream(url:String) {
			super();
			_tc = new TakConnection(this);
			_tc.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
			_tc.connect(url);
		}
		/**
		 * NetStatusEvent処理
		 */
		private function onNetStatus(event:NetStatusEvent):void {
			if(event.info.code == "NetConnection.Connect.Success") {
				if(name != null && !requestDataInvoked) {
					Logger.info("requestData invoke... with netStatus");
					_tc.call("requestData", null, name);
					requestDataInvoked = true;
				}
			}
		}
		/**
		 * 放送の開始
		 */
		override public function play(... parameters):void {
			name = parameters[0]; // parametersから放送名を入手する。
			if(initialized) {
				_tc.call("requestData", null, name);
				requestDataInvoked = true;
			}
		}
		/**
		 * close処理
		 */
		override public function close():void {
			initialized = false;
			requestDataInvoked = false;
			_tc.close();
			super.close();
		}
		/**
		 * headerデータを受け取った場合の処理
		 */
		public function headerData(data:ByteArray):void {
			crc = data.readInt();
			setup();
			var header:ByteArray = new ByteArray();
			data.readBytes(header);
			appendHeaderBytes(header);
		}
		/**
		 * bodyデータをうけとった場合の処理
		 */
		public function bodyData(data:ByteArray):void {
			var size:int = data.readInt();
			Logger.info(size);
			if(crc != data.readInt()) {
				Logger.info("crc is invalid");
				_tc.close();
			}
			var num:int = data.readInt();
			appendAggregateBytes(data);
		}
	}
}