あたらしいバージョンのtakStreamを生成するためのred5実装

名称:
takStreamRed5

内容:
taktodが自作したtakStreaming用のrtmpSegmentデータを応答するred5アプリケーション実装。
red5サーバーにpublishしたデータをrtmpTakStreamingとして応答します。

ライセンス:
LGPLとします。

作者:
taktod
email poepoemix@hotmail.com
twitter http://twitter.com/taktod/

tak/WEB-INF/lib/takRed5.jar
               /red5-web.properties
               /red5-web.xml
               /web.xml
をred5サーバーのRED5_ROOT/webapps/にコピーしてください。
rtmp://(your address)/tak
にrtmpで放送を実施すると
http://49.212.39.17/player/TakStreamingPlayer.html
こちらのプレーヤーに
アドレス:rtmp://(your address)/tak
放送名:上記の放送にあわせる
で視聴できます。

今後:
・とりあえずred5のservlet機能経由でhttpTakStreaming再生ができるようにしておきたい。