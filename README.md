# postgis_LayerTransform
一个在postgis中结合中国国情，批量对数据进行加偏到百度坐标，高德谷歌的火星坐标，或者逆向纠偏
# 安装：
  在postgresql-postgis空间数据库中，执行sql文件中语句即可。
# 使用：
select LayerTransform(
	in inputlayer text,--输入图层名字
	in transformtype transform_type--转换类型枚举型。
)
如在psql中输入: select LayerTransform('road','GCJ2WGS'); 回车执行该语句即可，等待完成。该示例代码是将 road表从火星坐标系转往84坐标系。
## 参数说明：
  inputlayer：输入的表名称，是个要加/纠偏的table名称，table是个空间表。  
  transformtype：加/纠偏方式，支持以下6种'BD2GCJ', 'GCJ2BD', 'WGS2GCJ','GCJ2WGS','BD2WGS','WGS2BD'，分别代表 百度转谷歌高德，谷歌高德转百度，84转火星，火星转84，百度转84,84转百度。
## 效果图
  
