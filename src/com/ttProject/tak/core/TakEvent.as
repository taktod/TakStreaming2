package com.ttProject.tak.core
{
	import flash.events.NetStatusEvent;

	/**
	 * イベント定義
	 * 基本NetStatusEventと同じにしておきます。
	 */
	public class TakEvent extends NetStatusEvent {
		public static const TAK_EVENT:String = "takEvent";
		/**
		 * コンストラクタ
		 */
		public function TakEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false, info:Object=null) {
			super(type, bubbles, cancelable, info);
		}
	}
}