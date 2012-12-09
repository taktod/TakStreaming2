package com.ttProject.red5;

import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;
import java.util.Queue;

import org.red5.io.ITag;

/**
 * flvの要素の順番を整列させる。
 * @author taktod
 */
public class TagOrderManager {
	private final Queue<ITag> audioTagQueue = new LinkedList<ITag>();
	private ITag lastAudioTag = null;
	public void reset() {
		lastAudioTag = null;
		audioTagQueue.clear();
	}
	public void clearPrestartTag(int timestamp) {
		getPassedData(timestamp);
	}
	public void addAudioTag(final ITag tag) {
		audioTagQueue.add(tag);
	}
	public List<ITag> getPassedData(int timestamp) {
		List<ITag> result = new ArrayList<ITag>();
		ITag audioTag = lastAudioTag;
		lastAudioTag = null;
		do {
			if(audioTag == null) {
				audioTag = audioTagQueue.poll();
			}
			if(audioTag == null) {
				break;
			}
			if(audioTag.getTimestamp() > timestamp) {
				lastAudioTag = audioTag;
				break;
			}
			result.add(audioTag);
			audioTag = null;
		} while(true);
		// 応答を返す。
		return result;
	}
}
