package com.ttProject.tak.rtmfp
{
	import com.ttProject.info.Logger;
	import com.ttProject.tak.core.BaseStream;
	
	import flash.events.NetStatusEvent;
	import flash.events.TimerEvent;
	import flash.net.GroupSpecifier;
	import flash.net.NetConnection;
	import flash.net.NetGroup;
	import flash.utils.Timer;

	/**
	 * rtmfpからデータをうけとる動作
	 * NetGroupのreplication
	 * 1:全アクセス
	 * 2:偶数アクセス
	 * 3:奇数アクセス
	 * 4:spotアクセス
	 * とします。
	 * シーケンスアクセスは
	 */
	public class RtmfpTakStream extends BaseStream {
		private var p2p:String;
		private var stream:String;

		private var nc:NetConnection = null;
		private var ng:NetGroup = null;
		private var timer:Timer = null;
		// 子接続監視(とりあえずFullChildrenのみ調べておく)
		private var fullChildren:Array = [];

		private var isSourceOrigin:Boolean = true; // originストリームに直接つながっているかどうか
		private var isWaitMode:Boolean = true; // 子接続待ち状態か確認する。
		public function RtmfpTakStream(stream:String, p2p:String, subp2p:String) {
			super();
			this.p2p = p2p;
			this.stream = stream;
			if(p2p != null) {
				nc = new NetConnection();
				nc.addEventListener(NetStatusEvent.NET_STATUS, onNetConnectionEvent);
				nc.connect(p2p);
				
				// 監視用のタイマーイベントをつくっておく。
				var d:Date = new Date();
				timer = new Timer(2000 + d.time % 2000); // タイマーの間隔はちょっとばらけておく。(接続先をうまくみつけるため。)
				timer.addEventListener(TimerEvent.TIMER, onTimerEvent);
				timer.start();
			}
		}
		/**
		 * 一定期間ごとのタイマーイベント
		 */
		private function onTimerEvent(event:TimerEvent):void {
			// netGroupの接続を監視しておく。自分につながっているユーザーがいない場合はhaveObjectsを解除して、wantObjectsを要求する。
			// 自分のデータソースがoriginの場合でかつ、childrenがいない場合はあたらしい接続を要求する必要がある。
			if(ng == null) {
				return;
			}
			if(isWaitMode) {
				// 誰かの接続をまっている状態の場合は、自分が他の人に接続する
				isWaitMode = false;
//				Logger.info("接続先を探す。");
				ng.removeHaveObjects(1,1);
				ng.addWantObjects(1,1);
			}
			else {
				isWaitMode = true;
//				Logger.info("接続受け入れ状態になる。");
				ng.removeWantObjects(1,1);
				ng.addHaveObjects(1,1);
			}
		}
		private function onNetConnectionEvent(event:NetStatusEvent):void {
			switch(event.info.code) {
				case "NetConnection.Connect.Success":
					// このタイミングでnetGroupに接続させる。
					var groupSpec:GroupSpecifier = new GroupSpecifier(stream);
					groupSpec.ipMulticastMemberUpdatesEnabled = true;
					groupSpec.addIPMulticastAddress("224.0.0.255:30000");
					groupSpec.objectReplicationEnabled = true;
					ng = new NetGroup(nc, groupSpec.groupspecWithAuthorizations());
					ng.addEventListener(NetStatusEvent.NET_STATUS, onNetGroupEvent);
					break;
				case "NetConnection.Connect.Close":
				case "NetConnection.Connect.NetworkChanged":
					break;
				case "NetGroup.Connect.Success":
					// とりあえずつながったらhaveObjectsを登録しておき、自分につながるようにしておく。
					// つながりにくるやつがいなかったら、別のユーザーに接続を試みる。
					ng.addHaveObjects(1,1); // とりあえず3種類全部OKになるようにしておく。
					isWaitMode = true;
					break;
				default:
					break;
			}
		}
		private function onNetGroupEvent(event:NetStatusEvent):void {
			Logger.info("onNetGroupEvent:" + event.info.code);
			switch(event.info.code) {
				case "NetGroup.Replication.Request":
					// 自分のnearIDを応答しておく。
					// 応答するデータはnetStreamで利用する名前と接続先のnearIDとします。
					var name:String = getRandomText();
					ng.writeRequestedObject(event.info.requestID, name + ":" + nc.nearID);
					var sc:SendConnection = new SendConnection(name, nc);
					break;
				case "NetGroup.Replication.Fetch.SendNotify":
					break;
				case "NetGroup.Replication.Fetch.Result":
//					Logger.info("応答をもらったindex:" + event.info.index);
//					Logger.info("応答をもらったデータ:" + event.info.object);
					// 応答をもらったらとりあえずそこにつなげばよい。
					var data:Array = (event.info.object as String).split(":");
					// 接続をしたら、はじめに、接続ソースについて応答するので、そのソースと自分のIDが一致しなければ、相手につないでよいことになる。
					var rc:RecvConnection = new RecvConnection(data[0], data[1], nc);
					break;
			}
		}
		// 継承先クラスのメソッドを呼び出すことが可能みたいですね。
		protected function test():void {
			Logger.info("rtmfp");
		}
		/**
		 * 20文字の適当なデータを応答する。
		 */
		private function getRandomText():String {
			return new Array(20).map(
				function(...param):* {
					if(Math.random() < 0.5) {
						return String.fromCharCode("A".charCodeAt(0) + Math.random() * 26);
					}
					else {
						return int(Math.random() * 10);
					}
				}
			).join("");
		}
	}
}