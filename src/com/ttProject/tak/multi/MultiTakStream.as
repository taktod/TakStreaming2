package com.ttProject.tak.multi
{
	import com.ttProject.info.Logger;
	import com.ttProject.tak.core.TakStream;
	
	import flash.events.NetStatusEvent;
	import flash.net.GroupSpecifier;
	import flash.net.NetConnection;
	import flash.net.NetGroup;

	/**
	 * 複数のTakStreamをあわせたTakStreamオブジェクト
	 * 
	 * subp2pは設定されている場合に、受け流すネットワークをsubp2pにします。
	 * 
	 * originが設定されている場合は、すぐにそのoriginにつなぎます。
	 * つないで視聴している間にp2pのネットワークにも接続を実行し、そちらからデータが取得できるなら、そっちから動作させます。
	 * 
	 * streamは流すstream名 rtmpの場合の放送名に相当し、rtmfpの場合は接続するnetGroupに相当させます。
	 * 
	 * originが設定されていない場合は、p2pネットワークから是が非でもデータを取得しようとします。
	 * p2pは
	 * netGroupのreplicationを利用してデータをやりとりします。
	 * ネットワークに対して特定のindexを要求すると接続相手の情報が入手できます。
	 * 1:full接続用アクセス 全部のデータが送信されます。
	 * 2:half接続用アクセス 偶数 or 奇数のデータのみ転送します。回線の放送ユーザーが親になる際の動作です。
	 * halfは２つ接続しないと成立しません。
	 * 3:spot接続用アクセス 指定したindexを送るとそのデータを応答する接続。さらに回線が遅いユーザー用です。
	 * 回線がはやくても念のため接続しておきます。(データ欠損を検知したらそこからデータを補完します。)
	 * 
	 * 相手に接続したら、ダウンロードもとの情報を送る
	 * これが自分である場合はそのダウンロードはあきらめる。
	 */
	public class MultiTakStream extends TakStream {
		private var origin:String;
		private var p2p:String;
		private var subp2p:String;
		private var stream:String;

		private var _ncP2p:NetConnection = null;
		private var _ngP2p:NetGroup = null;

		// とりあえずsubp2pは無視しておく。
//		private var _ncSubp2p:NetConnection = null;
//		private var _ngSubp2p:NetGroup = null;
		public function MultiTakStream(
				origin:String,
				stream:String,
				p2p:String,
				subp2p:String = "") {
			super();
			this.origin = origin;
			this.p2p = p2p;
			this.subp2p = subp2p;
			this.stream = stream;
			if(origin != null && origin != "") {
				// originが設定されている場合
				// 通常のダウンロードストリーミングを実施します。
				makeOriginConnection();
			}
			makeP2pConnection();
		}
		private function makeOriginConnection():void {
			
		}
		private function makeP2pConnection():void {
			_ncP2p = new NetConnection();
			_ncP2p.addEventListener(NetStatusEvent.NET_STATUS, onP2pNetConnectionEvent);
			_ncP2p.connect(p2p);
		}
		private function onP2pNetConnectionEvent(event:NetStatusEvent):void {
			Logger.info("onP2pNetConnection:" + event.info.code);
			switch(event.info.code) {
				case "NetConnection.Connect.Success":
					// netGroupを作る必要がある。
					makeP2pGroup();
					break;
				case "NetConnection.Connect.Closed":
				case "NetConnection.Connect.NetworkChanged":
					// おわるときの処理?
					break;
			}
		}
		private function makeP2pGroup():void {
			Logger.info("try to create netgroup");
			var groupSpec:GroupSpecifier = new GroupSpecifier(stream);
			groupSpec.serverChannelEnabled = true;
			groupSpec.ipMulticastMemberUpdatesEnabled = true;
			groupSpec.addIPMulticastAddress("224.0.0.255:30000");
			groupSpec.postingEnabled = true;
			groupSpec.objectReplicationEnabled = true;
			_ngP2p = new NetGroup(_ncP2p, groupSpec.groupspecWithAuthorizations());
			_ngP2p.addEventListener(NetStatusEvent.NET_STATUS, onP2pNetGroupEvent);
		}
		private function onP2pNetGroupEvent(event:NetStatusEvent):void {
			Logger.info("onP2pNetGroup:" + event.info.code);
			switch(event.info.code) {
				case "NetGroup.Connect.Success":
					// 接続できたら接続先を問い合わせる。
					_ngP2p.addWantObjects(1,7); // 1〜7まで情報を要求する。
					break;
				case "NetGroup.Neighbor.Connect":
					Logger.info("人数:" + _ngP2p.estimatedMemberCount);
					break;
				case "NetGroup.Posting.Notify":
					// postingで何らかのメッセージをやりとりする。
					break;
				case "NetGroup.Replication.Request":
					// replicationの要求をうけた場合応答を返す必要がある。
				case "NetGroup.Replication.Fetch.SendNotify":
				case "NetGroup.Replication.Fetch.Result":
					// 受信した結果
				case "NetGroup.Replication.Fetch.Failed":
					break;
			}
		}
	}
}