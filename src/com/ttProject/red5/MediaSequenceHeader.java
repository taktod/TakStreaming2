package com.ttProject.red5;

import java.util.ArrayList;
import java.util.List;

import org.red5.io.ITag;

public class MediaSequenceHeader {
	private ITag aacMediaSequenceHeader = null;
	private ITag avcMediaSequenceHeader = null;
	public List<ITag> getData() {
		List<ITag> result = new ArrayList<ITag>();
		if(aacMediaSequenceHeader != null) {
			aacMediaSequenceHeader.setTimestamp(0);
			result.add(aacMediaSequenceHeader);
		}
		if(avcMediaSequenceHeader != null) {
			avcMediaSequenceHeader.setTimestamp(0);
			result.add(avcMediaSequenceHeader);
		}
		return result;
	}
	public void resetAacMediaSequenceHeader() {
		aacMediaSequenceHeader = null;
	}
	public void resetAvcMediaSequenceHeader() {
		avcMediaSequenceHeader = null;
	}
	public boolean isAacMediaSequenceHeader(final ITag tag, final CodecType codec, byte checkByte) {
		if(codec == CodecType.AAC && checkByte == 0x00) {
			aacMediaSequenceHeader = tag;
			return true;
		}
		else if(codec != CodecType.AAC) {
			aacMediaSequenceHeader = null;
		}
		return false;
	}
	public boolean isAvcMediaSequenceHeader(final ITag tag, final CodecType codec, byte checkByte) {
		if(codec == CodecType.AVC && checkByte == 0x00) {
			avcMediaSequenceHeader = tag;
			return true;
		}
		else if(codec != CodecType.AVC) {
			avcMediaSequenceHeader = null;
		}
		return false;
	}
}
