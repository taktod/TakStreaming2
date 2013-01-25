package com.ttProject.tak.core
{
	import com.ttProject.tak.Logger;
	import com.ttProject.tak.data.BaseStream;
	import com.ttProject.tak.data.DataManager;
	import com.ttProject.tak.source.HttpStream;
	
	/**
	 * TakStreamingのベースとなるStream
	 * 動作はそれぞれのオブジェクトに任せています。
	 * (若干未完成)
	 */
	public class TakStream extends BaseStream {
		// データ管理
		private var dataManager:DataManager;
		// sourceがどこであるかの印(あとで削除する予定)
		public var source:String;
		/**
		 * コンストラクタ
		 */
		public function TakStream() {
			super();
			dataManager = new DataManager(this);
		}
		/**
		 * 動画データの取得元を追加する。
		 */
		public function addSource(url:String, name:String):void {
			dataManager.addSource(url, name);
		}
		/**
		 * 動画データの取得元を削除する。
		 */
		public function removeSource(url:String, name:String):void {
		}
		/**
		 * 動画データの取得元一覧取得
		 */
		public function getSourceList():Object {
			return null;
		}
		/**
		 * 供給先の設定
		 */
		public function addSupply(url:String, name:String):void {
			dataManager.addSupply(url, name);
		}
		/**
		 * supplyに指定されているデータを参照する。
		 */
		public function getSupply():Object {
			return null;
		}
		/**
		 * 視聴開始処理
		 */
		override public function play(...parameters):void {
			dataManager.start();
		}
	}
}
