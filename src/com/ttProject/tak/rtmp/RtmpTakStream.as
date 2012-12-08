package com.ttProject.tak.rtmp
{
	import com.ttProject.tak.core.TakStream;
	
	/**
	 * rtmpの接続はrtmpサーバーに接続してデータをダウンロードしていきます。
	 * dlに失敗した場合はrtmpで補完できるか確認して、できるならそこでやり直す。
	 * httpで補完可能な場合はそちらでもやり直す。
	 */
	public class RtmpTakStream extends TakStream
	{
		public function RtmpTakStream()
		{
			super();
		}
	}
}