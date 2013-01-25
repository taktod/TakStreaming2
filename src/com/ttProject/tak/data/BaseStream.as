package com.ttProject.tak.data
{
	import com.ttProject.tak.Logger;
	import com.ttProject.tak.core.TakEvent;
	
	import flash.events.NetStatusEvent;
	import flash.media.SoundTransform;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.NetStreamAppendBytesAction;
	import flash.utils.ByteArray;
	
	/**
	 * 映像の処理を実施するコアストリーム
	 * 基本部分データをうけとったら映像にして、ごにょごにょするよ。
	 */
	public class BaseStream extends NetStream {
		// 管理用オブジェクト
		private var startPos:int;				// 開始timestamp保持
		private var initFlg:Boolean;			// 初期化済みフラグ
		private var lastVideoTimestamp:uint;	// 最終videoのtimestamp(受け取ったデータが過去のデータの場合は、処理にまわさない。)
		private var lastAudioTimestamp:uint;	// 最終audioのtimestamp(同上)
		// プロパティー用データ
		private var _client:Object;
		private var _bufferTime:Number;
		private var _soundTransform:SoundTransform;
		// 動作用オブジェクト
		private var ns:NetStream;
		private var nc:NetConnection;
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
		override public function get audioCodec():uint {
			if(ns != null) {return ns.audioCodec;}
			return 0;
		}
		override public function get videoCodec():uint {
			if(ns != null) {return ns.videoCodec;}
			return 0;
		}
		public function get _ns():NetStream {
			return ns;
		}
		/**
		 * コンストラクタ
		 */
		public function BaseStream() {
			initFlg	= false;
			ns				= null;
			_client 		= null;
			_soundTransform	= null;
			startPos	= -1;
			_bufferTime	= -1;
			lastAudioTimestamp	= 0;
			lastVideoTimestamp	= 0;

			nc = new NetConnection;
			nc.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
			nc.connect(null);

			super(nc);
		}
		/**
		 * 停止処理
		 */
		override public function close():void {
			if(ns != null) {
				ns.close();
				ns = null;
			}
		}
		/**
		 * セットアップ
		 */
		public function setup():Boolean {
			if(!initFlg) {
				// 初期化完了前の場合はエラーを返しておく。
				return false;
			}
			close(); // 前の接続がある場合はクリアしておく。
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
			startPos = -1;
			lastAudioTimestamp = 0;
			lastVideoTimestamp = 0;
			dispatchEvent(new TakEvent(TakEvent.TAK_EVENT, false, false, {code:"TakEvent.Setup.OK"}));
			return true;
		}
		/**
		 * 内部コネクト成立処理
		 */
		private function onNetStatus(event:NetStatusEvent):void {
			dispatchEvent(new NetStatusEvent(event.type, event.bubbles, event.cancelable, event.info));
			if(event.info.code == "NetConnection.Connect.Success") {
				initFlg = true;
				dispatchEvent(new NetStatusEvent(NetStatusEvent.NET_STATUS, false, false, {code:"TakStream.Initialize.OK"}));
			}
		}
		/**
		 * headerデータ処理
		 * この中では、確実にflvの始まりデータとavcやaacの場合はmediaSequenceHeaderをいれる必要がある。
		 */
		public function appendHeaderBytes(data:ByteArray):void {
			if(initFlg && ns != null) {
				startPos = -1;
				lastAudioTimestamp = 0;
				lastVideoTimestamp = 0;
				ns.appendBytesAction(NetStreamAppendBytesAction.RESET_BEGIN);
				ns.appendBytes(data);
				ns.appendBytesAction(NetStreamAppendBytesAction.RESET_BEGIN);
				ns.appendBytes(data);
			}
		}
		public function appendSingleDataBytes(rawdata:ByteArray):void {
			// リロードすると２つ同時に読み込みがすすむっぽいのがおかしい。
			if(initFlg && ns != null) {
				var data:ByteArray = timestampInjection(rawdata);
				if(data != null) {
					ns.appendBytes(data);
				}
			}
		}
		/**
		 * データ追記処理
		 */
		public function appendDataBytes(rawdata:ByteArray):void {
			if(initFlg && ns != null) {
				// 複数のデータを同時にinsertする必要がでることがある。
				try {
					var position:uint = 0;
					while(rawdata.length > rawdata.position) {
						position = rawdata.position;
						var size:int = (rawdata.readInt() & 0x00FFFFFF) + 11 + 4;
						var tmpdata:ByteArray = new ByteArray();
						rawdata.position = position;
						rawdata.readBytes(tmpdata, 0, size);
						var data:ByteArray = timestampInjection(tmpdata);
						if(data != null) {
							ns.appendBytes(data);
						}
					}
				}
				catch(e:Error) {
					Logger.info("error発生:" + e.toString());
				}
			}
		}
		/**
		 * timestampを再生するのに合わせた形に変化させておく。
		 */
		private function timestampInjection(data:ByteArray):ByteArray {
			var ba:ByteArray = new ByteArray;
			ba.writeBytes(data);
			try {
				ba.position = 0;
				var dataType:int = ba.readByte();
				if(startPos == -1) {
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
						newTimestamp = timestamp - startPos;
						break;
					case 9: // video
						if(startPos == -1) {
							startPos = timestamp;
						}
						if(timestamp < lastVideoTimestamp) {
							return null;
						}
						lastVideoTimestamp = timestamp;
						newTimestamp = timestamp - startPos;
						break;
					case 18: // meta
						newTimestamp = timestamp - startPos;
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