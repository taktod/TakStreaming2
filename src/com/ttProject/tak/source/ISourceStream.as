package com.ttProject.tak.source
{
	/**
	 * sourceとなるstreamのインターフェイス
	 * 
	 * ここにsourceとなるstreamが持つべき関数を書き込んでおきます。
	 * 
	 * spot動作も入れておいた方がいいんだろうか・・・
	 */
	public interface ISourceStream {
		// 勝手にDLするので、特に定義するものはなし。
		// startとcloseくらいは実装しておいてもいいかも
		function hashCode():String;
		// ダウンロード主体になっているか確認する
		function get isTarget():Boolean;
		// ダウンロード主体設定を変更する。
		function set target(val:Boolean):void;
		// 動作を開始する。
		function start(... paramter):void;
		// 動作を停止する。
		function stop():void;
	}
}