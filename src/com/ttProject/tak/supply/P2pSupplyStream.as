package com.ttProject.tak.supply
{
	import com.ttProject.tak.Logger;
	import com.ttProject.tak.data.DataManager;

	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.utils.ByteArray;

	/**
	 * p2pのsupplyとするときのベースとなる動作
	 * 接続したら一定間隔ごとに、コネクトがくることになっている。
	 * コネクトがこなくなったら接続が死亡したと判定しておわらせる。
	 * 
	 * 現状のままだと、pingデータがいつまでまってもこないので、ずっと動作エラーになるっぽい。
	 */
	public class P2pSupplyStream implements ISupplyStream {
		private var sendStream:NetStream;
		private var nodeId:String = null;
		private var name:String;
		private var lastAccess:Number;
		private var sendHeader:Boolean;
		private var dataManager:DataManager;
		private var counter:int = 0;

		public function get isSendHeader():Boolean {
			return sendHeader;
		}
		/**
		 * 接続確認
		 * true:接続している。false:切断してしまった。
		 */
		public function get connected():Boolean {
			if(sendStream == null) {
				return false;
			}
			return ((new Date()).time - lastAccess) < 3000; // 8秒以上経っている場合は接続していないとして応答する
		}
		/**
		 * 相手のID
		 */
		public function get farID():String {
			return nodeId;
		}
		/**
		 * コンストラクタ
		 */
		public function P2pSupplyStream(name:String, nc:NetConnection, dataManager:DataManager) {
			this.name = name;
			this.dataManager = dataManager;
			sendStream = new NetStream(nc, NetStream.DIRECT_CONNECTIONS);
			sendStream.client = new Object();
			// 相手から接続がきたときの処理
			sendStream.client.onPeerConnect = function(subscriber:NetStream):Boolean {
				// 相互接続は不可能っぽい。
				// 一定時間接続がこなくなったら、死んだものとする。
				lastAccess = (new Date()).time;
				if(nodeId == null) {
					nodeId = subscriber.farID;
					Logger.info("supply接続しました。:" + nodeId);
					sendHeader = false;
				}
				return true; // とりあえず許可しておく
			};
			sendStream.publish(name);
			lastAccess = (new Date()).time;
		}
		/**
		 * タイマーイベント動作
		 */
		public function onTimerEvent():void {
			try {
				counter ++;
				if(counter > 10) {
					if(sendStream != null) {
						sendStream.send("onPing", null);
					}
					counter = 0;
				}
			}
			catch(e:Error) {
				Logger.error("onTimerEvent(P2pSupplyStream):" + e.message);
			}
		}
		/**
		 * 停止処理
		 */
		public function stop():void {
			close();
		}
		/**
		 * 閉じる動作
		 */
		private function close():void {
			if(sendStream != null) {
				sendStream.close();
				sendStream = null;
			}
		}
		/**
		 * データを送信する。
		 */
		protected function send(func:String, ...data):void {
			sendStream.send(func, data);
		}
		public function flm(data:ByteArray):void {
			sendStream.send("takData", data);
		}
		public function flh(data:ByteArray):void {
			sendStream.send("takHeader", data);
		}
		public function initFlh(data:ByteArray):void {
			sendHeader = true;
			sendStream.send("takInitHeader", data);
		}
		public function hashCode():String {
			return "p2pSupply:" + name;
		}
	}
}
