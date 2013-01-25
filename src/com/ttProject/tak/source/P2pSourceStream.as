package com.ttProject.tak.source
{
	import com.ttProject.tak.Logger;
	import com.ttProject.tak.data.DataManager;
	import com.ttProject.tak.data.RtmfpConnection;
	
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.utils.ByteArray;

	/**
	 * p2pをsourceとするときのベースとなる動作
	 * 
	 * 接続したら一定間隔ごとに、接続を繰り返して接続しているアピールを実行しておく。
	 * データがながれてこなくなったら元が死んだと判定して、おわらせる。
	 * 接続間隔は10秒データ転送が3秒なくなったら死んだ物とする。
	 */
	public class P2pSourceStream implements ISourceStream {
		private var nc:NetConnection;
		private var recvStream:NetStream;
		private var pingStream:NetStream;
		private var name:String;
		private var nodeId:String;
		private var lastAccess:Number;
		private var dataManager:DataManager;
		private var rtmfp:RtmfpConnection;
		private var counter:int = 0;

		private var _target:Boolean;
		public function get isTarget():Boolean {
			return _target;
		}
		public function set target(val:Boolean):void {
			_target = val;
		}
		/**
		 * 接続確認
		 * true:接続している。false:切断してしまった。
		 */
		public function get connected():Boolean {
			if(recvStream == null) {
				return false;
			}
			return ((new Date()).time - lastAccess) < 3000; // 3秒以上経っている場合は接続していないとして応答する
		}
		/**
		 * 接続先の情報を取得する。
		 */
		public function get farID():String {
			return nodeId;
		}
		/**
		 * コンストラクタ
		 */
		public function P2pSourceStream(name:String, nodeId:String, nc:NetConnection, dataManager:DataManager, rtmfp:RtmfpConnection) {
			this.rtmfp = rtmfp;
			this._target = false;
			this.dataManager = dataManager;
			this.name = name;
			this.nodeId = nodeId;
			this.nc = nc;
			recvStream = new NetStream(nc, nodeId); // 接続先のnodeId
			recvStream.client = new Object();
			// 相手からのpingをうけとります。
			recvStream.client.onPing = function(data:*):void {
				lastAccess = (new Date()).time;
			};
			recvStream.client.takData = takData;
			recvStream.client.takHeader = takHeader;
			recvStream.client.takInitHeader = takInitHeader;
			recvStream.client.takSource = takSource;
			pingStream = new NetStream(nc, nodeId);
			start();
		}
		/**
		 * 開始する。
		 * メソッドは準備していますが、とりあえず勝手にはじまるようにしておきます。
		 */
		public function start(...paramter):void {
			recvStream.play(name);
			lastAccess = (new Date()).time;
		}
		/**
		 * タイマー動作
		 * ping実行
		 */
		public function onTimerEvent():void {
			try {
				counter ++;
				if(counter > 5) {
					if(nc != null && nc.connected && pingStream != null) {
						pingStream.play(name);
					}
					counter = 0;
				}
			}
			catch(e:Error) {
				Logger.error("onTimerEvent(P2pSourceStream):" + e.message);
			}
		}
		/**
		 * 停止する。
		 */
		public function stop():void {
			close();
		}
		/**
		 * 停止させる。
		 */
		private function close():void {
			if(recvStream != null) {
				Logger.info("親接続と切れました:" + nodeId);
				recvStream.close();
				recvStream = null;
			}
			if(pingStream != null) {
				pingStream.close();
				pingStream = null;
			}
		}
		private function takData(data:ByteArray):void {
			dataManager.setFlmData(data);
		}
		private function takHeader(data:ByteArray):void {
			dataManager.setFlhData(data);
		}
		/**
		 * p2pのご先祖様の情報をやりとりする命令
		 */
		private function takSource(nodeId:String):void {
			rtmfp.masterNodeId = nodeId; // ご先祖さま登録
		}
		/**
		 * p2pのアクセスで始めに送られてくるheader情報
		 */
		private function takInitHeader(data:ByteArray):void {
			dataManager.setInitFlhData(data);
		}
		public function hashCode():String {
			return "p2pSource:" + name;
		}
	}
}