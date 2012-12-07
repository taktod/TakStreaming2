package com.ttProject.segment.flf;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * flfのデータを処理するためのマネージャー
 * @author taktod
 * 
 * flfの中身
 * vodの場合
 * #FLF_EXT // 宣言
 * #FLF_HEADER:
 * http://49.212.39.17/flf/test.flh
 * #FLF_DATA:3
 * http://49.212.39.17/flf/test_1.flm
 * #FLF_DATA:3
 * http://49.212.39.17/flf/test_2.flm
 * #FLF_DATA:3
 * http://49.212.39.17/flf/test_3.flm
 * #FLF_DATA:3
 * http://49.212.39.17/flf/test_4.flm
 * #FLF_DATA:3
 * http://49.212.39.17/flf/test_5.flm
 * #FLF_DATA:3
 * http://49.212.39.17/flf/test_6.flm
 * #FLF_ENDLIST
 * 
 * liveの場合
 * #FLF_EXT // 宣言
 * #FLF_HEADER:
 * http://49.212.39.17/flf/test.flh
 * #FLF_DATA:3
 * http://49.212.39.17/flf/test_208.flm
 * 
 * 最終データのみ保持しておく。
 */
public class FlfManager {
	private static final Map<String, FlfManager> managerMap = new HashMap<String, FlfManager>();
	private final Logger logger = LoggerFactory.getLogger(FlfManager.class);
	private final String header;
	private String flhFile;
	private List<FlfElement> elementData;
	private final String flfFile;
	private final int limit = 20;
	private int num;
	public static FlfManager getInstance(String flfFile) {
		FlfManager instance = managerMap.get(flfFile);
		if(instance == null) {
			instance = new FlfManager(flfFile);
			managerMap.put(flfFile, instance);
		}
		return instance;
	}
	private FlfManager(String flfFile) {
		this.flfFile = flfFile;
		header = "#FLF_EXT";
		elementData = new ArrayList<FlfElement>();
		num = 0;
	}
	public void setFlhFile(String flhFile) {
		this.flhFile = flhFile;
	}
	public void writeData(String target, String http, float duration, int index, boolean endFlg) {
		FlfElement element = new FlfElement(target, http, duration, index);
		elementData.add(element);
		if(elementData.size() > limit) {
			FlfElement removedData = elementData.remove(0);
			File deleteFile = new File(removedData.getFile());
			if(deleteFile.exists()) {
				deleteFile.delete();
			}
		}
		try {
			PrintWriter pw = new PrintWriter(new BufferedWriter(new FileWriter(flfFile, false)));
			pw.println(header);
			pw.print("#FLF_COUNTER:");
			pw.println(elementData.get(0).getCount());
			pw.println("#FLF_HEADER:");
			pw.println(flhFile);
			num ++;
			for(FlfElement data : elementData) {
//				if(data.isFirst()) {
//				}
				pw.println(data.getInfo());
				pw.println(data.getHttp());
			}
//			if(endFlg) {
///			}
			pw.close();
			pw = null;
		}
		catch (Exception e) {
			logger.error("flfファイル書き込み中にエラー", e);
		}
	}
}
