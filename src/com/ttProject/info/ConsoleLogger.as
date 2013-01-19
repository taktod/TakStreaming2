package com.ttProject.info
{
	import flash.external.ExternalInterface;

	/**
	 * ExternalInterfaceでConsole.logにデータを出力するロガー
	 */
	public class ConsoleLogger {
		public const OFF:int	= 0;
		public const ERROR:int	= 1;
		public const WARN:int	= 2;
		public const INFO:int	= 3;
		public const DEBUG:int	= 4;
		private var level:int	= INFO;
		public function setLevel(level:int):void {
			this.level = level;
		}
		public function error(msg:String):void {
			ExternalInterface.call("console.error", msg);
		}
		public function warn(msg:String):void {
			ExternalInterface.call("console.warn", msg);
		}
		public function info(msg:String):void {
			ExternalInterface.call("console.log", msg);
		}
		public function debug(msg:String):void {
			ExternalInterface.call("console.debug", msg);
		}
	}
}