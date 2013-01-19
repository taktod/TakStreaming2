package com.ttProject.tak
{
	/**
	 * ロガー動作補助
	 */
	public class Logger {
		private static var logger:*;
		public static function setLogger(logger:*):void {
			Logger.logger = logger;
		}
		public static function debug(msg:String):void {
			try {
				logger.debug(msg);
			}
			catch(e:Error) {
			}
		}
		public static function info(msg:String):void {
			try {
				logger.info(msg);
			}
			catch(e:Error) {
			}
		}
		public static function warn(msg:String):void {
			try {
				logger.warn(msg);
			}
			catch(e:Error) {
			}
		}
		public static function error(msg:String):void {
			try {
				logger.error(msg);
			}
			catch(e:Error) {
			}
		}
	}
}