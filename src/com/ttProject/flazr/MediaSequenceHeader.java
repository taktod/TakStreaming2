package com.ttProject.flazr;

import java.util.ArrayList;
import java.util.List;

import com.flazr.io.flv.AudioTag;
import com.flazr.io.flv.FlvAtom;
import com.flazr.io.flv.VideoTag;

/**
 * aacとavcのmediaSequenceHeader
 * @author taktod
 */
public class MediaSequenceHeader {
	private FlvAtom aacMediaSequenceHeader = null;
	private FlvAtom avcMediaSequenceHeader = null;
	/**
	 * MediaSequenceHeaderリストを取得します。(開始時用)
	 * @return
	 */
	public List<FlvAtom> getData() {
		List<FlvAtom> result = new ArrayList<FlvAtom>();
		if(aacMediaSequenceHeader != null) {
			aacMediaSequenceHeader.getHeader().setTime(0);
			result.add(aacMediaSequenceHeader);
		}
		if(avcMediaSequenceHeader != null) {
			avcMediaSequenceHeader.getHeader().setTime(0);
			result.add(avcMediaSequenceHeader);
		}
		return result;
	}
	/**
	 * aacのheaderであるか確認
	 * @param flvAtom
	 * @param tag
	 * @param checkByte
	 * @return
	 */
	public boolean isAacMediaSequenceHeader(final FlvAtom flvAtom, final AudioTag tag, byte checkByte) {
		if(tag.getCodecType() == AudioTag.CodecType.AAC && checkByte == 0x00) {
			aacMediaSequenceHeader = flvAtom;
			return true;
		}
		return false;
	}
	/**
	 * avcのheaderであるか確認
	 * @param flvAtom
	 * @param tag
	 * @param checkByte
	 * @return
	 */
	public boolean isAvcMediaSequenceHeader(final FlvAtom flvAtom, final VideoTag tag, byte checkByte) {
		if(tag.getCodecType() == VideoTag.CodecType.AVC && checkByte == 0x00) {
			avcMediaSequenceHeader = flvAtom;
			return true;
		}
		return false;
	}
}
