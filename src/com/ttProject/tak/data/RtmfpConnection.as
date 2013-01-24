package com.ttProject.tak.data
{
	import com.ttProject.tak.Logger;
	import com.ttProject.tak.source.P2pSourceStream;
	import com.ttProject.tak.supply.P2pSupplyStream;
	
	import flash.events.NetStatusEvent;
	import flash.events.TimerEvent;
	import flash.net.GroupSpecifier;
	import flash.net.NetConnection;
	import flash.net.NetGroup;
	import flash.net.NetStream;
	import flash.utils.Timer;

	/**
	 * rtmfpのコネクションをつくって、p2pどうしのやりとりを作成するためのコネクション
	 * 
	 * とりあえず1DL 2UPが理想的
	 * ただ、帯域が細いユーザーもいるはずなので、将来的には偶数や奇数のindexデータのみ送信するものもつくっておいて、すこしでも帯域に貢献できるようにしたい。
	 * 
	 * とりあえずいまのところ1DL 2UP強制にしてある
	 */
	public class RtmfpConnection {
		private var _masterNodeId:String;
		public function set masterNodeId(val:String):void {
			if(val == nc.nearID) {
				// 自分のIDにもどってきた場合はなにかがおかしい。
				if(sourceStream1 != null) {
					sourceStream1.stop();
					sourceStream1 = null;
				}
				_masterNodeId = null;
				return;
			}
			// すでに指定されていたご先祖が再度ご先祖であると伝搬された場合
			if(_masterNodeId == val) {
				return;
			}
			_masterNodeId = val;
			if(supplyStream1 != null) {
				supplyStream1.source(val);
			}
			if(supplyStream2 != null) {
				supplyStream2.source(val);
			}
		}
		public function get masterNodeId():String {
			// masterNodeIdが決定していない状態で問い合わせがあった場合、自分がご先祖になってる。
			if(_masterNodeId == null) {
				if(sourceStream1 != null) {
					sourceStream1.stop();
					sourceStream1 = null;
				}
				return nc.nearID;
			}
			return _masterNodeId;
		}
		private var url:String; // 動作URL
		private var name:String; // group名
		private var dataManager:DataManager; // データ管理マネージャー
		// タイマー動作の待機データ長保持
		private var waitCount:int;
		// 待機用のカウンター
		private var counter:int;
		
		// p2p網作成用
		private var nc:NetConnection;
		private var ng:NetGroup;

		// 動作モード(両立可能)
		private var sourceFlg:Boolean; // このp2pからデータを受け取る
		public function set source(flg:Boolean):void {
			if(sourceFlg != flg) {
				sourceFlg = flg;
				changeMode();
			}
		}
		public function get source():Boolean {return sourceFlg;}

		private var supplyFlg:Boolean; // このp2pにデータを送信する
		public function set supply(flg:Boolean):void {
			if(supplyFlg != flg) {
				supplyFlg = flg;
				changeMode();
			}
		}
		public function get supply():Boolean {return supplyFlg;}

		// 接続データ一覧
		private var supplyStream1:P2pSupplyStream = null;
		private var supplyStream2:P2pSupplyStream = null;
		private var sourceStream1:P2pSourceStream = null;
		
		private var mode:int = 1; // とりあえず、1ならダウンロード調査中 2ならアップロード先受付中

		/**
		 * コンストラクタ
		 */
		public function RtmfpConnection(url:String, name:String, dataManager:DataManager, sourceFlg:Boolean=false, supplyFlg:Boolean=false) {
			this._masterNodeId = null;
			this.url = url;
			this.name = name;
			this.nc = null;
			this.ng = null;
			this.sourceFlg = sourceFlg;
			this.supplyFlg = supplyFlg;
			this.dataManager = dataManager;
			this.counter = 0;
		}
		/**
		 * ネット関連のイベント処理
		 */
		private function onNetStatusEvent(event:NetStatusEvent):void {
			switch(event.info.code) {
				case "NetConnection.Connect.Success":
					// 接続成功したら、groupをつくっておく。
					connectGroup();
					Logger.info("自分[" + nc.nearID + "]");
					break;
				case "NetConnection.Connect.Close":
				case "NetConnection.Connect.NetworkChanged":
					// 切断した場合は、あたらしい接続をつくりなおす必要がある。(ただしタイマーでやることにする。)
//					resumeConnection();
					break;
				case "NetGroup.Connect.Success":
					// netgroupにつながったら必要な相手をみつける作業にはいる。
					changeMode(); // モードをフラグにあわせたものにする。
					break;
				case "NetGroup.Replication.Request":
					// リクエストをうけとった場合の処理
					var name:String = (new TokenGenerator()).getRandomText();
					// 相手がみつかった、次の接続をうけいれるかは、タイマーで監視することにする。
					if(supplyStream1 == null && dataManager.supplyCount != 2) {
						try {
							ng.writeRequestedObject(event.info.requestID, name + ":" + nc.nearID);
							supplyStream1 = new P2pSupplyStream(name, nc, dataManager, this);
							dataManager.addSupplyStream(supplyStream1);
						}
						catch(e:Error) {
							Logger.info("error:ee:" + e.message);
						}
					}
					else if(supplyStream2 == null && dataManager.supplyCount != 2) {
						try {
							ng.writeRequestedObject(event.info.requestID, name + ":" + nc.nearID);
							supplyStream2 = new P2pSupplyStream(name, nc, dataManager, this);
							dataManager.addSupplyStream(supplyStream2);
						}
						catch(e:Error) {
							Logger.info("error:ee:" + e.message);
						}
					}
					else {
						ng.denyRequestedObject(event.info.requestID);
					}
					clearQueue();
					break;
				case "NetGroup.Replication.Fetch.Result":
					// 応答をうけとったときの処理
					Logger.info(event.info.object as String);
					// 接続がきまったときに次の接続をうけいれるか確認する必要あり
					if(sourceStream1 == null && !dataManager.hasP2pSource) {
						var data:Array = (event.info.object as String).split(":");
						sourceStream1 = new P2pSourceStream(data[0], data[1], nc, dataManager, this);
						Logger.info("sourcestream1決定しました。");
						// データの取得元のsourceStreamを設定しておく。
						dataManager.addSourceStream("rtmfp:" + url, sourceStream1);
					}
					clearQueue();
					break;
				case "NetGroup.Replication.Fetch.Failed":
					// 応答をうけとったが失敗したときの処理
					break;
			}
		}
		/**
		 * groupに接続する。
		 */
		private function connectGroup():void {
			var groupSpec:GroupSpecifier = new GroupSpecifier(name);
			if(url == "rtmfp:") {
				groupSpec.ipMulticastMemberUpdatesEnabled = true;
				groupSpec.addIPMulticastAddress("224.0.0.255:30000");
			}
			groupSpec.objectReplicationEnabled = true;
			ng = new NetGroup(nc, groupSpec.groupspecWithAuthorizations());
			ng.addEventListener(NetStatusEvent.NET_STATUS, onNetStatusEvent);
		}
		/**
		 * 接続を開始する
		 */
		public function startConnection():void {
			resumeConnection();
			
			// 動作コントロールに必要な処理を実行しておく。
			var d:Date = new Date();
			waitCount = 20 + d.time % 50;
		}
		/**
		 * 切断されてしまったコネクションを復帰させる。
		 */
		private function resumeConnection():void {
			closeConnection();
			nc = new NetConnection;
			nc.addEventListener(NetStatusEvent.NET_STATUS, onNetStatusEvent);
			nc.connect(url);
			// 一時的なタイマーなので、許可しておく。
			var timer:Timer = new Timer(4.0, 1);
			timer.addEventListener(TimerEvent.TIMER, function(event:TimerEvent):void {
				try {
					// 確認を実行して接続できていなかったら再接続を実施する。
					if(!nc.connected) {
						// 接続できていない場合は再トライする。(接続可能になるまでリトライしておく。)
						resumeConnection();
					}
				}
				catch(e:Error) {
					Logger.error("function(TimerEvent)(RtmfpConnection):" + e.message);
				}
			});
		}
		/**
		 * 全接続をすてて停止する。
		 */
		public function closeConnection():void {
			if(ng != null) {
				ng.close();
				ng = null;
			}
			if(nc != null) {
				nc.close();
				nc = null;
			}
		}
		/**
		 * 相手に送ることが可能な状態であることをqueueに出す
		 */
		private function supplyQueue():void {
			clearQueue();
			if(dataManager.supplyCount < 2 && (supplyStream1 == null || supplyStream2 == null)) {
				ng.addHaveObjects(1, 1);
			}
		}
		/**
		 * 相手から受け取ることが可能な状態であることをqueueに出す
		 */
		private function sourceQueue():void {
			clearQueue();
			// 全体でp2pのソースが存在していない場合
			if(!dataManager.hasP2pSource) {
				// 仮にsourceStream1がのこっている場合はおかしいので、とめておく。
				if(sourceStream1 != null) {
					sourceStream1.stop();
					sourceStream1 = null;
				}
				// ご先祖さまがあるわけがないので、クリアしておく
				_masterNodeId = null;
				ng.addWantObjects(1, 1);
			}
		}
		/**
		 * 設定queueをクリアする
		 */
		private function clearQueue():void {
			ng.removeHaveObjects(1, 1);
			ng.removeWantObjects(1, 1);
		}
		/**
		 * 動作モードがかわったときの処理
		 * TODO halfコネクションとか考えてどのindex待ちにするか決めておく必要あり。
		 */
		private function changeMode():void {
			if(nc == null || !nc.connected || ng == null) {
				// 接続していないので、放置(netConnection -> netGroupから実行がくるのでタイマーによる監視とかいらない。)
				return;
			}
			// 接続可能モードでも、必要があれば、接続をうけつけなくしたりコントロールしないとだめ。
			if(supply && source) {
				// タイマーによる動作の監視を実施する？
				if(dataManager.hasP2pSource) {
					// p2pのソースをもっている場合は提供先を探したい。
					mode = 1;
				}
				// 他の接続と共用している可能性があるので、データ転送があってもソース枠があいているなら探す。
				if(mode == 1) {
					mode = 2;
					// supplyするよ状態に変更する。
					supplyQueue();
				}
				else {
					mode = 1;
					// sourceほしい状態に変更する。
					sourceQueue();
				}
			}
			else if(supply) {
				// 提供するよコネクションのみつくる
				supplyQueue();
			}
			else if(source) {
				// 取得ほしいコネクションのみつくる
				sourceQueue();
			}
			else {
				// 両方のコネクションをつくらない(意味ないがこういう状況もまぁできると思う)
				clearQueue();
			}
		}
		/**
		 * 一定時間ごとに呼び出される動作確認
		 */
		public function onTimerEvent():void {
			try {
				if(nc == null || !nc.connected) {
					return;
				}
				counter ++;
				if(counter < waitCount) {
					return;
				}
				// タイマーで動作を監視しておきます。
				// 死んでる接続はけしておく。
				if(sourceStream1 != null && !sourceStream1.connected) {
					sourceStream1.stop();
					sourceStream1 = null;
					// ソースの接続がなくなった場合には、
					if(_masterNodeId != null) {
						_masterNodeId = null;
						Logger.info("ご先祖さまがいなくなった。");
					}
				}
				if(supplyStream1 != null && !supplyStream1.connected) {
					supplyStream1.stop();
					supplyStream1 = null;
				}
				if(supplyStream2 != null && !supplyStream2.connected) {
					supplyStream2.stop();
					supplyStream2 = null;
				}
				// モードを変更しておく。
				changeMode();
				counter = 0;
			}
			catch(e:Error) {
				Logger.error("onTimerEvent(RtmfpConnection):" + e.message);
			}
		}
	}
}

/**
 * 接続時トークンの生成補助
 */
class TokenGenerator {
	public function getRandomText():String {
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