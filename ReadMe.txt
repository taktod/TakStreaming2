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
いまのところrtmfpの接続をより安定させたいのだが、そうなると、httpのstreamの動作をシビアにするしかない
(flfのダウンロード密度を向上させて、flmデータが生成されたら即DLする方向にもっていかないとだめ)
httpStream + rtmfpStreamの動作は動作する感じになってきた。

[rtmfp:]を指定したときにLAN内の接続を試みるようにしてみた。

処置済み問題
・ストリームがおわってやり直しになったときの動作が微妙(止まる？)
・たまーに止まる
・rtmfpの接続がなくなったあとにhttpのsequence接続に戻る動作をつくっていない。
・rtmfpの接続を複数許可するとそれぞれに2up 1dlしようとするので、全体で2up 1dlになるように調整しないとだめ。(済み)

でも、まだ問題はある。
１：rtmpでの動作をつくってタイマー監視しなくてもリアルタイムに動作できるようにしたい。
２：PC上のlfvデータをベースにストリームできるようなものをつくる。
３：global経由でのデータの共有はどうなるかわからない。
(個人的なルーターの問題だと思われるけど、きちんと調査して動作できるようにしたい。)
４：rtmfpのhalf接続をつくって回線の遅いユーザーでもrtmfpに寄与できるようにしたい。
５：rtmfpの動作で複数ソース状態をつくれるようにする。
(rtmfpの疎通状態がわるくなってもhttpに戻らず他のrtmfp接続で補完するようにすることでもっと安定したp2p動作にする。)
６：中途セグメントでも通信できるようにしたい。
(いまのところcompleteしたflmセグメントしか扱えないようにしてあるが、フォーマット的には中途データを共有して復元できるようにしたつもり
中途データをつかえるようにしたら、遅延をさらに縮めたり安定供給したりできるはず。)

やっておきたいこと。
・配信も可能な適当なデモをつくって公開しておきたい。
