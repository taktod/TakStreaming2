package com.ttProject.tak.source
{
	import com.ttProject.tak.data.DataManager;
	
	import flash.events.NetStatusEvent;

	/**
	 * rtmpストリーム由来のストリームを実施する。
	 * つくったけど、動作するかはわからない。未実験
	 */
	public class RtmpStream implements ISourceStream {
		private var tc:TakConnection;
		private var name:String;
		private var url:String;
		private var initialized:Boolean;
		private var requestDataInvoked:Boolean = false;
		
		private var _target:Boolean;
		public function get isTarget():Boolean {
			return _target;
		}
		public function set target(val:Boolean):void {
			_target = val;
		}
		/**
		 * コンストラクタ
		 */
		public function RtmpStream(url:String, dataManager:DataManager) {
			this.target = false;
			this.url = url;
			tc = new TakConnection(dataManager);
			tc.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
			tc.connect(url);
		}
		/**
		 * サーバーに接続時の動作
		 */
		private function onNetStatus(event:NetStatusEvent):void {
			if(event.info.code == "NetConnection.Connect.Success") {
				initialized = true;
				if(name != null && !requestDataInvoked) {
					tc.call("requestData", null, name);
					requestDataInvoked = true;
				}
			}
		}
		/**
		 * 開始処理
		 */
		public function start(...parameter):void {
			this.name = parameter[0];
			if(initialized && !requestDataInvoked) {
				tc.call("requestData", null, name);
				requestDataInvoked = true;
			}
		}
		/**
		 * 閉じる
		 */
		public function close():void {
			tc.close();
			initialized = false;
			requestDataInvoked = false;
		}
		public function hashCode():String {
			return "rtmp:" + url + ":" + name;
		}
	}
}
import com.ttProject.tak.data.DataManager;

import flash.net.NetConnection;
import flash.utils.ByteArray;
import flash.utils.Endian;

class TakConnection extends NetConnection {
	private var dataManager:DataManager;
	/**
	 * コンストラクタ
	 */
	public function TakConnection(dataManager:DataManager) {
		super();
		this.dataManager = dataManager;
	}
	/**
	 * flhデータをうけとる場合の動作
	 */
	public function takHeader(data:*):void {
		var ba:ByteArray = makeByteArray(data);
		dataManager.setFlhData(ba);
	}
	/**
	 * flmデータを受け取る場合の動作
	 */
	public function takData(data:*):void {
		var ba:ByteArray = makeByteArray(data);
		dataManager.setFlmData(ba);
	}
	/**
	 * rawデータを受け取る場合の動作
	 */
	public function takRawData(index:int, data:*):void {
		
	}
	/**
	 * 配列からByteArrayを生成します。
	 */
	private function makeByteArray(data:Array):ByteArray {
		var ba:ByteArray = new ByteArray();
		ba.endian = Endian.BIG_ENDIAN;
		for(var i:int = 0;i < data.length;i ++) {
			ba.writeByte(data[i]);
		}
		ba.position = 0;
		return ba;
	}
}