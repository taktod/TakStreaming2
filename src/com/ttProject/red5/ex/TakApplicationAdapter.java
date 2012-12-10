package com.ttProject.red5.ex;

import org.red5.server.adapter.ApplicationAdapter;
import org.red5.server.api.IConnection;
import org.red5.server.api.scope.IScope;
import org.red5.server.api.service.IServiceCapableConnection;
import org.red5.server.api.stream.IBroadcastStream;

import com.ttProject.red5.RtmpStreamObserver;

/**
 * takStream用のApplicationAdapter
 * @author taktod
 */
public class TakApplicationAdapter extends ApplicationAdapter {
	// segmentに関する情報
	private static float duration = 2;
	private static int limit = 20;
	public static float getDuration() {
		return duration;
	}
	public static int getLimit() {
		return limit;
	}
	public void setDuration(float val) {
		duration = val;
	}
	public void setLimit(int val) {
		limit = val;
	}
	// pathに関する情報
	private static String filePath = null;
	private static String httpPath = null;
	public static String getFilePath() {
		return filePath;
	}
	public static String getHttpPath() {
		return httpPath;
	}
	public void setFilePath(String val) {
		filePath = val;
	}
	public void setHttpPath(String val) {
		httpPath = val;
	}
	@Override
	public synchronized void disconnect(IConnection conn, IScope scope) {
		// 閉じるとき動作
		for(String name : getAttributeNames()) {
			if(name.startsWith("rtmpStreamObserver:")) {
				Object obj = getAttribute(name);
				if(obj != null && obj instanceof RtmpStreamObserver) {
					RtmpStreamObserver observer = (RtmpStreamObserver)obj;
					observer.removeConn(conn);
				}
			}
		}
		super.disconnect(conn, scope);
	}
	/**
	 * ストリーム開始命令
	 */
	@Override
	public void streamBroadcastStart(IBroadcastStream stream) {
		super.streamBroadcastStart(stream);
		// streamにlistenerをくっつける。
		String targetName = getName(stream.getScope(), stream.getPublishedName());
		RtmpStreamObserver observer = null;
		Object obj = getAttribute(targetName);
		if(obj != null && obj instanceof RtmpStreamObserver) {
			observer = (RtmpStreamObserver)obj;
		}
		else {
			observer = new RtmpStreamObserver(stream.getScope().getContextPath() + "/" + stream.getPublishedName());
		}
		stream.addStreamListener(observer);
		setAttribute(targetName, observer);
	}
	/**
	 * ストリーム停止命令
	 */
	@Override
	public void streamBroadcastClose(IBroadcastStream stream) {
		Object obj = getAttribute(getName(stream.getScope(), stream.getPublishedName()));
		if(obj != null && obj instanceof RtmpStreamObserver) {
			RtmpStreamObserver observer = (RtmpStreamObserver)obj;
			stream.removeStreamListener(observer);
			observer.stop();
		}
		// 停止する処理がある場合
		super.streamBroadcastClose(stream);
	}
	// requestをうけとってから、動作を調整する。
	public String requestData(IConnection conn, String name, Integer index) {
		System.out.println("spot request:" + name + ":" + index);
		return "";
	}
	public String requestData(IConnection conn, String name) {
		// streamにlistenerをくっつける。
		String targetName = getName(conn.getScope(), name);
		RtmpStreamObserver observer = null;
		Object obj = getAttribute(targetName);
		if(obj != null && obj instanceof RtmpStreamObserver) {
			observer = (RtmpStreamObserver)obj;
		}
		else {
			observer = new RtmpStreamObserver(conn.getScope().getContextPath() + "/" + name);
		}
		if(conn instanceof IServiceCapableConnection) {
			observer.addStreamClient((IServiceCapableConnection)conn);
		}
		setAttribute(targetName, observer);
		return "";
	}
	private String getName(IScope scope, String streamName) {
		StringBuilder name = new StringBuilder();
		name.append("rtmpStreamObserver:").append(scope.getName()).append(":").append(scope.getPath()).append(":").append(streamName);
		System.out.println(name.toString());
		return name.toString();
	}
}
