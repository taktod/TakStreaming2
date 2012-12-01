package com.ttProject.flazr;

import java.util.LinkedList;
import java.util.List;
import java.util.Queue;

import com.flazr.io.flv.FlvAtom;

/**
 * flvの要素の順番を整列させる。
 * @author taktod
 */
public class AtomOrderManager {
	/** 整頓用のqueue */
	private final Queue<FlvAtom> audioAtomQueue = new LinkedList<FlvAtom>();
	/** 先頭に入るべき最終キュー */
	private FlvAtom lastAudioAtom = null;
	/**
	 * リセットする。
	 */
	public void reset() {
		lastAudioAtom = null;
		audioAtomQueue.clear();
	}
	/**
	 * 処理開始前のatomをクリア
	 */
	public void clearPrestartAtom(int timestamp) {
		getPassedData(timestamp);
	}
	/**
	 * オーディオデータを登録する。
	 * @param flvAtom
	 */
	public void addAudioAtom(final FlvAtom flvAtom) {
		audioAtomQueue.add(flvAtom);
	}
	/**
	 * 登録すべきデータを取り出します。
	 * @return
	 */
	public List<FlvAtom> getPassedData(int timestamp) {
		List<FlvAtom> result = new LinkedList<FlvAtom>();
		FlvAtom audioAtom = lastAudioAtom;
		lastAudioAtom = null;
		do {
			if(audioAtom == null) {
				audioAtom = audioAtomQueue.poll();
			}
			if(audioAtom == null) {
				break;
			}
			if(audioAtom.getHeader().getTime() > timestamp) {
				lastAudioAtom = audioAtom;
				break;
			}
			result.add(audioAtom);
			audioAtom = null;
		} while(true);
		// 応答を返す。
		return result;
	}
}
