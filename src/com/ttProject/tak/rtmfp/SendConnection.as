package com.ttProject.tak.rtmfp
{
	import com.ttProject.info.Logger;
	
	import flash.events.NetStatusEvent;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.utils.ByteArray;

	/**
	 * spot動作だけ、大本のユーザーへのコネクションが必要
	 */
	public class SendConnection {
		private static var sendStream:NetStream = null;
		private static var recvStream:NetStream = null;
		private var name:String;
		private var nodeId:String;
		public function SendConnection(name:String, nc:NetConnection) {
			if(sendStream != null) {
				sendStream.close();
			}
			// この接続に利用する名前を設定
			this.name = name;
			sendStream = new NetStream(nc, NetStream.DIRECT_CONNECTIONS);
			sendStream.addEventListener(NetStatusEvent.NET_STATUS, onNetStreamEvent);
			sendStream.client = new Object();
			sendStream.client.onPeerConnect = function(subscriber:NetStream):Boolean {
				// 接続前に相手の情報を入手できる。
				// これで相手の情報が取得できる。
				nodeId = subscriber.farID;
				recvStream = new NetStream(nc, nodeId);
				recvStream.client = new Object();
				recvStream.client.test = function(data:*):void {
					Logger.info("sendConnectionへの要求データ:" + data);
				}
				recvStream.play(nc.nearID);
				return true;
			};
			sendStream.publish(name);
		}
		public function close():void {
			sendStream.close();
		}
		private function onNetStreamEvent(event:NetStatusEvent):void {
//			Logger.info("sendConn:" + event.info.code);
		}
		public function sendFlhData(data:ByteArray):void {
			sendStream.send("flhData", data);
		}
		public function sendFlmData(data:ByteArray):void {
			sendStream.send("flmData", data);
		}
		public function sendSourceNode(data:String):void {
			sendStream.send("sourceNode", data);
		}
	}
}