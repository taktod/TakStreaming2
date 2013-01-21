あたらしいバージョンのtakStreamを扱うためのFlashプログラム(仮)

名称:
TakStreamLibrary

内容:
taktodが自作したtakStreamingのデータを再生するようのライブラリ、デモプレーヤー付き

ライセンス:
LGPLとします。

作者:
taktod
email poepoemix@hotmail.com
twitter http://twitter.com/taktod/

使い方:
1:データ元を設定する。
TakStreamingFactory.addSource(url:String, name:String):void;
2:mediaオブジェクトをもらう
TakStreamingFactory.getStream():NetStream;
TakStreamingFactory.getVideo():Video;

master.mxmlとslave.mxmlが参考になると思います。

更新内容:
まだ作成中。動作はするけど、停止したときのレジュームとかつくってない。
とりあえず、httpStream + rtmfpStreamの動作は動作する感じになってきた。

[rtmfp:]を指定したときにLAN内の接続を試みるようにしてみた。

でも、まだ問題はある。
１：ストリームがおわってやり直しになったときの動作が微妙(止まる？)
２：たまーに止まる
３：http前提でしかつくっていない
４：rtmfpの接続がなくなったあとにhttpのsequence接続に戻る動作をつくっていない。
５：global経由でのデータの共有はどうなるかわからない。
６：rtmfpのhalf接続とかはまだつくってない
７：PC上のflvデータをベースにストリームする動作もつくってない。
８：rtmfpの接続を複数許可するとそれぞれに2up 1dlしようとするので、全体で2up 1dlになるように調整しないとだめ。(済み)
