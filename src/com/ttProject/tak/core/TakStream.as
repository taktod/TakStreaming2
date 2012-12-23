package com.ttProject.tak.core
{
	import com.ttProject.info.Logger;
	
	import flash.events.EventDispatcher;
	import flash.events.NetStatusEvent;
	import flash.media.Sound;
	import flash.media.SoundTransform;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.NetStreamAppendBytesAction;
	import flash.utils.ByteArray;

	/**
	 * 根幹となるストリームオブジェクト
	 * 基本NetStreamに合わせておいてユーザーとしてはNetStreamと同じようにつかえるようにしておきたい。
	 */
	public class TakStream extends NetStream {
		private var initializeFlg:Boolean;
		private var nc:NetConnection;
		private var ns:NetStream;
		// 時間管理まわり
		private var startPosition:int;
		private var lastVideoTimestamp:uint;
		private var lastAudioTimestamp:uint;

		// haderデータ保持
		private var headerData:ByteArray;
		// プロパティーとなるデータ
		private var _client:Object;
		private var _soundTransform:SoundTransform;
		private var _bufferTime:Number;
		// プロパティー
		override public function get bufferLength():Number {
			if(ns != null) {return ns.bufferLength;}
			return -1;
		}
		override public function get bufferTime():Number {
			if(ns != null) {return ns.bufferTime;}
			return _bufferTime;
		}
		override public function set bufferTime(value:Number):void {
			if(ns != null) {ns.bufferTime = value;}
			_bufferTime = value;
		}
		override public function get bytesLoaded():uint {
			if(ns != null) {return ns.bytesLoaded;}
			return 0;
		}
		override public function get bytesTotal():uint {
			if(ns != null) {return ns.bytesTotal;}
			return 0;
		}
		override public function set client(value:Object):void {
			if(ns != null) {ns.client = value;}
			_client = value;
		}
		override public function get currentFPS():Number {
			if(ns != null) {return ns.currentFPS;}
			return -1;
		}
		override public function set soundTransform(value:SoundTransform):void {
			if(ns != null) {ns.soundTransform = value;}
			_soundTransform = value;
		}
		override public function get soundTransform():SoundTransform {
			if(ns != null) {return ns.soundTransform;}
			return _soundTransform;
		}
		override public function get time():Number {
			if(ns != null) {return ns.time;}
			return -1;
		}
		override public function get liveDelay():Number {
			if(ns != null) {return ns.liveDelay;}
			return -1;
		}
		public function get _ns():NetStream {
			return ns;
		}
		// 以下処理
		/**
		 * コンストラクタ
		 */
		public function TakStream() {
			initializeFlg = false;
			ns            = null;

			startPosition = -1;
			lastAudioTimestamp = 0;
			lastVideoTimestamp = 0;

			headerData = null;

			_client         = null;
			_soundTransform = null;
			_bufferTime     = -1;

			nc = new NetConnection();
			nc.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
			nc.connect(null);
			// superしたくねぇ・・・
			super(nc);
		}
		/**
		 * 閉じる動作
		 * netStreamだけとめる。
		 */
		override public function close():void {
			if(ns != null) {
				ns.close();
				ns = null;
			}
		}
		/**
		 * 動作開始前に実行するセットアップ動作
		 */
		protected function setup():Boolean {
			if(!initializeFlg) {
				return false;
			}
			Logger.info("try setup");
			ns = new NetStream(nc);
			ns.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
			ns.bufferTime = 0;
			if(_client != null) {
				ns.client = _client;
			}
			if(_soundTransform != null) {
				ns.soundTransform = _soundTransform;
			}
			if(_bufferTime != -1) {
				ns.bufferTime = _bufferTime;
			}
			ns.play(null);
			startPosition = -1;
			lastAudioTimestamp = 0;
			lastVideoTimestamp = 0;
			dispatchEvent(new TakEvent(TakEvent.TAK_EVENT, false, false, {code:"TakEvent.Start"}));
			return true;
		}
		/**
		 * 内部イベント処理
		 */
		private function onNetStatus(event:NetStatusEvent):void {
			Logger.info(event.info.code);
			dispatchEvent(new TakEvent(event.type, event.bubbles, event.cancelable, event.info));
			if(event.info.code == "NetConnection.Connect.Success") {
				initializeFlg = true;
				dispatchEvent(new TakEvent(event.type, event.bubbles, event.cancelable, {code:"TakEvent.Initialized"}));
			}
		}
		/**
		 * headerデータ処理
		 * この中では、確実にflvの始まりデータとavcやaacの場合はmediaSequenceHeaderをいれる必要がある。
		 */
		protected function appendHeaderBytes(data:ByteArray):void {
			if(initializeFlg && ns != null) {
				startPosition = -1;
				lastAudioTimestamp = 0;
				lastVideoTimestamp = 0;
				headerData = data;
				Logger.info("headerSize:" + headerData.length);
				ns.appendBytesAction(NetStreamAppendBytesAction.RESET_BEGIN);
				ns.appendBytes(headerData);
				ns.appendBytesAction(NetStreamAppendBytesAction.RESET_BEGIN);
				ns.appendBytes(headerData);
				// endSequenceによる強制開始は必要なさそう。
				headerData.position = 0;
			}
		}
		/**
		 * データをnetStreamに流す(生バージョン)
		 */
		protected function appendRawBytes(rawdata:ByteArray):void {
			if(initializeFlg && ns != null) {
				ns.appendBytes(rawdata);
			}
		}
		/**
		 * データ追記処理
		 */
		protected function appendDataBytes(rawdata:ByteArray):void {
			// リロードすると２つ同時に読み込みがすすむっぽいのがおかしい。
			if(initializeFlg && ns != null) {
				var data:ByteArray = timestampInjection(rawdata);
				if(data != null) {
					ns.appendBytes(data);
				}
			}
		}
		/**
		 * シークをリセットする。(とりあえずつかってない。)
		 */
		protected function resetSeek():void {
			if(ns != null) {
				ns.appendBytesAction(NetStreamAppendBytesAction.RESET_SEEK);
			}
		}
		/**
		 * チャンクデータ追記処理
		 * flvのデータの塊を分解して処理する。
		 */
		protected function appendAggregateBytes(rawdata:ByteArray):void {
			// flvデータとしてデータが渡されていることを期待します。
			var length:uint = rawdata.length;
			// デバッグ用エラー時に吐くメッセージ
			var status:String = "";
			try {
				do {
					status = "try rawdata...;";
					var position:uint = rawdata.position;
					var size:int = (rawdata.readInt() & 0x00FFFFFF) + 11 + 4;
					status += "get size:" + size + ";";
					rawdata.position = position;
					var data:ByteArray = new ByteArray();
					status += "read data;";
					// 11バイト抜き出す。
					rawdata.readBytes(data, 0, size);
					status += "append try;";
					appendDataBytes(data);
					position += size;
					status += "position now:" + position;
					if(position >= length) {
						break;
					}
				}while(true);
			}
			catch(e:Error) {
				Logger.info(status);
				Logger.info("動作エラー:" + e.toString());
			}
		}
		/**
		 * この関数は１パケットだけ分だけ処理するように考慮されてつくられている。
		 * 現行のflmFileみたいに１つのファイルに複数パケットデータがはいっているとうまく動作できない。
		 */
		private function timestampInjection(data:ByteArray):ByteArray {
			var ba:ByteArray = new ByteArray;
			ba.writeBytes(data);
			try {
				ba.position = 0;
				var dataType:int = ba.readByte();
				if(startPosition == -1) {
					switch(dataType) {
						case 8: // audio
							return null;
						case 18: // meta
							ba.position = 0;
							return ba;
						case 9: // video
							ba.position = 11;
							if(ba.readByte() & 0x10 == 0x00) {
								return null;
							}
							break;
						default:
							return null;
					}
				}
				ba.position = 4;
				var timestamp:uint = ((ba.readByte() + 0x0100) & 0xFF) * 0x010000
					+ ((ba.readByte() + 0x0100) & 0xFF) * 0x0100
					+ ((ba.readByte() + 0x0100) & 0xFF) * 0x01
					+ ((ba.readByte() + 0x0100) & 0xFF) * 0x01000000;
				var newTimestamp:uint = 0;
				switch(dataType) {
					case 8: // audio
						if(timestamp < lastAudioTimestamp) {
							return null;
						}
						lastAudioTimestamp = timestamp;
						newTimestamp = timestamp - startPosition;
						break;
					case 9: // video
						if(startPosition == -1) {
							startPosition = timestamp;
						}
						if(timestamp < lastVideoTimestamp) {
							return null;
						}
						lastVideoTimestamp = timestamp;
						newTimestamp = timestamp - startPosition;
						break;
					case 18: // meta
						newTimestamp = timestamp - startPosition;
						break;
					case 20: // eof
						dispatchEvent(new TakEvent(TakEvent.TAK_EVENT, false, false, {code:"FlvEvent.Unpublish"}));
						return null;
					default: // unknown
						return null;
				}
				ba.position = 4;
				ba.writeByte((newTimestamp / 0x010000) & 0xFF);
				ba.writeByte((newTimestamp / 0x0100) & 0xFF);
				ba.writeByte((newTimestamp / 0x01) & 0xFF);
				ba.writeByte((newTimestamp / 0x01000000) & 0xFF);
				ba.position = 0;
			}
			catch(e:Error) {
				Logger.info("time injection error:" + e.toString());
			}
			return ba;
		}
	}
}