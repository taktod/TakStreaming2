package com.ttProject.tak.supply
{
	import flash.utils.ByteArray;

	/**
	 * supplyとなるstreamにインターフェイス
	 * 
	 * ここにsupplyとなるstreamが持つべき関数を書き込んでおく。
	 */
	public interface ISupplyStream {
		/**
		 * flmデータを相手に送信する。
		 */
		function flm(data:ByteArray):void;
		/**
		 * flhデータを相手に送信する。
		 * (このメソッドは中途でreset命令がきて、flhデータを更新する場合の動作)
		 */
		function flh(data:ByteArray):void;
		/**
		 * 初期のflhデータを相手に送信する。
		 * (このメソッドは開始時に確実に相手にflhデータを送るための動作)
		 */
		function initFlh(data:ByteArray):void;
		/**
		 * 停止する。
		 */
		function stop():void;
		/**
		 * 動作のhashCode(接続に対して一意)
		 */
		function hashCode():String;
		/**
		 * headerデータを送信済みか判定するフラグ
		 */
		function get isSendHeader():Boolean;
		/**
		 * 接続中か判定するフラグ
		 */
		function get connected():Boolean;
	}
}