package com.ttProject.tak.rtmfp
{
	import com.ttProject.tak.core.TakStream;
	
	/**
	 * rtmfpの接続は1/2ダウンロードも実装する。
	 * 2カ所以上から同時にダウンロードして、再生するが、内容は半々にするという・・・
	 * 
	 * 補完
	 */
	public class RtmfpTakStream extends TakStream
	{
		public function RtmfpTakStream()
		{
			super();
		}
	}
}
