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
		private var dataManager:DataManager; // データ管理マネージャー
		
		// タイマー用
		private var waitCount:int;
		private var counter:int;
		
		// p2p網作成用
		private var url:String; // 動作URL
		private var name:String; // group名
		private var nc:NetConnection;
		private var ng:NetGroup;
		private var _masterNodeId:String; // クラスタツリーの頂点Node(ご先祖様)のID

		// フラグ
		private var mode:int = 1; // とりあえず、1ならダウンロード調査中 2ならアップロード先受付中
		private var startFlg:Boolean;
		private var sourceFlg:Boolean; // このp2pからデータを受け取る
		private var supplyFlg:Boolean; // このp2pにデータを送信する

		// 接続データ一覧
		private var supplyStream1:P2pSupplyStream = null;
		private var supplyStream2:P2pSupplyStream = null;
		private var sourceStream1:P2pSourceStream = null;

		// 参照or設定
		public function set masterNodeId(val:String):void {
			// 自分のIDにもどってきた場合はなにかがおかしい。
			if(val == nc.nearID) {
				if(sourceStream1 != null) {
					sourceStream1.stop();
					sourceStream1 = null;
				}
				_masterNodeId = null;
				return;
			}
			// すでに取得済みなnodeのIDだった場合は、子孫に連絡する必要なし
			if(_masterNodeId == val) {
				return;
			}
			// 保持して連絡しておく。
			_masterNodeId = val;
			if(supplyStream1 != null) {
				supplyStream1.source(val);
			}
			if(supplyStream2 != null) {
				supplyStream2.source(val);
			}
		}
		public function get masterNodeId():String {
			// 自分のご先祖様がいるか確認
			if(_masterNodeId == null) {
				// いない場合ソースストリームが万一あったらとめとく
				if(sourceStream1 != null) {
					sourceStream1.stop();
					sourceStream1 = null;
				}
				// 自分がご先祖様になる。
				return nc.nearID;
			}
			// しっているご先祖様をお伝えする
			return _masterNodeId;
		}
		public function set source(flg:Boolean):void {
			if(sourceFlg != flg) {
				sourceFlg = flg;
				changeMode();
			}
		}
		public function get source():Boolean {return sourceFlg;}
		public function set supply(flg:Boolean):void {
			if(supplyFlg != flg) {
				supplyFlg = flg;
				changeMode();
			}
		}
		public function get supply():Boolean {return supplyFlg;}

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
			this.startFlg = false;
			
			// コンストラクタの時点でp2pに参加する
			resumeConnection();
		}
		/**
		 * ネット関連のイベント処理
		 */
		private function onNetStatusEvent(event:NetStatusEvent):void {
			switch(event.info.code) {
				case "NetConnection.Connect.Success": // netConnectionの接続成功時
					connectGroup();
					Logger.info("自分[" + nc.nearID + "]");
					break;
				case "NetConnection.Connect.Close": // ネットワークが閉じたとき
				case "NetConnection.Connect.NetworkChanged": // ネットワークが変わったとき
					resumeConnection();
					break;
				case "NetGroup.Connect.Success": // groupにアクセスできたとき
					if(startFlg) {
						// すでにplayボタンが押されている場合には、相手検索に入る
						changeMode(); // 状態変換して、接続先検索開始
					}
					break;
				case "NetGroup.Replication.Request": // リクエストをうけとったとき
					var name:String = (new TokenGenerator()).getRandomText();
					// 相手がみつかった接続できる枠があるか確認
					if(supplyStream1 == null && dataManager.supplyCount < 2) { // 枠１
						try {
							ng.writeRequestedObject(event.info.requestID, name + ":" + nc.nearID);
							supplyStream1 = new P2pSupplyStream(name, nc, dataManager, this);
							dataManager.addSupplyStream(supplyStream1);
						}
						catch(e:Error) {
							Logger.info("error:ee:" + e.message);
						}
					}
					else if(supplyStream2 == null && dataManager.supplyCount < 2) { // 枠２
						try {
							ng.writeRequestedObject(event.info.requestID, name + ":" + nc.nearID);
							supplyStream2 = new P2pSupplyStream(name, nc, dataManager, this);
							dataManager.addSupplyStream(supplyStream2);
						}
						catch(e:Error) {
							Logger.info("error:ee:" + e.message);
						}
					}
					else { // 枠なし、よって拒否しとく
						ng.denyRequestedObject(event.info.requestID);
					}
					// これ以上アクセスがこないようにqueueはいったんクリア
					clearQueue();
					break;
				case "NetGroup.Replication.Fetch.Result": // 相手からアクセスリクエストの応答があったとき
					// p2pのDL先枠があるか確認
					if(sourceStream1 == null && !dataManager.hasP2pSource) {
						var data:Array = (event.info.object as String).split(":");
						sourceStream1 = new P2pSourceStream(data[0], data[1], nc, dataManager, this);
						// データの取得元のsourceStreamを設定しておく。
						dataManager.addSourceStream("rtmfp:" + url, sourceStream1);
					}
					clearQueue();
					break;
				case "NetGroup.Replication.Fetch.Failed": // 相手からアクセス拒否されたとき
				default: // その他
					break;
			}
		}
		/**
		 * groupに接続する。
		 */
		private function connectGroup():void {
			var groupSpec:GroupSpecifier = new GroupSpecifier(name);
			if(url == "rtmfp:") { // サーバーを指定していない場合はLAN内だけでp2pする
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
			// timerの間隔はランダムできめておく。
			var d:Date = new Date();
			waitCount = 20 + d.time % 50;
			// 開始フラグON
			startFlg = true;
		}
		/**
		 * 切断されてしまったコネクションを復帰させる。
		 */
		private function resumeConnection():void {
			if(ng != null) {
				ng.close();
				ng = null;
			}
			if(nc != null) {
				nc.close();
				nc = null;
			}
			nc = new NetConnection;
			nc.addEventListener(NetStatusEvent.NET_STATUS, onNetStatusEvent);
			nc.connect(url);
			// タイマーで接続できなかった場合にレジュームできるようにしておく。(netConnection.Connect.Failedとか使えばいいのでは？と思った)
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
		 * p2p通信を閉じる
		 */
		public function closeConnection():void {
			clearQueue();
			if(sourceStream1 != null) {
				sourceStream1.stop();
			}
			if(supplyStream1 != null) {
				supplyStream1.stop();
			}
			if(supplyStream2 != null) {
				supplyStream2.stop();
			}
			startFlg = false;
		}
		/**
		 * 提供先募集
		 */
		private function supplyQueue():void {
			clearQueue();
			// アクセス数がひくくて、枠の空きがあるか確認
			if(dataManager.supplyCount < 2 && (supplyStream1 == null || supplyStream2 == null)) {
				ng.addHaveObjects(1, 1);
			}
		}
		/**
		 * データ元募集
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
		 * 募集をやめる。
		 */
		private function clearQueue():void {
			ng.removeHaveObjects(1, 1);
			ng.removeWantObjects(1, 1);
		}
		/**
		 * 動作モードを変更する処理
		 * TODO halfコネクションとか考えてどのindex待ちにするか決めておく必要あり。
		 */
		private function changeMode():void {
			// 接続確認
			if(nc == null || !nc.connected || ng == null) {
				return;
			}
			// 接続可能モードでも、必要があれば、接続をうけつけなくしたりコントロールしないとだめ。
			if(supply && source) { // 提供も受け入れもする場合
				// p2pのソースを取得済みの場合はもしくは、前回データソース募集した場合
				if(dataManager.hasP2pSource || mode == 1) {
					// データ提供先募集
					mode = 2;
					supplyQueue();
				}
				else {
					// データ取得元募集
					mode = 1;
					sourceQueue();
				}
			}
			else if(supply) { // 提供のみの場合
				supplyQueue();
			}
			else if(source) { // 取得のみの場合
				sourceQueue();
			}
			else { // どちらも実行しない場合
				clearQueue();
			}
		}
		/**
		 * タイマー動作
		 */
		public function onTimerEvent():void {
			try {
				// rtmfpの接続が成立していない場合 もしくは動作開始していない場合はなにもしない
				if(nc == null || !nc.connected || !startFlg) {
					return;
				}
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
				// タイマーの待ち時間に揺らぎをつくっておく。
				counter ++;
				if(counter < waitCount) {
					return;
				}
				counter = 0;
				// 相手参照モードを変更する
				changeMode();
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