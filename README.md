# 一 背景
GIS项目中底图是必不可少的，绝大部分GIS项目使用的底图是基于高德，谷歌，百度，天地图等互联网（在线/离线）底图。由于我国特殊国情，公众版地理信息服务（包括电子底图）都要进行各种坐标偏移旋转等数据加密处理，并获取国土资源部数据审查并颁发审图号才可公开发布。企业的GIS数据都是通过传感器或者实地测量获得的非加密的WGS84坐标（即常用的gps那种坐标），当企业将自己的业务数据叠加到互联网底图时，不可避免出现**图层叠加偏移**问题，如下图：
![图层叠加偏移.png](https://upload-images.jianshu.io/upload_images/68979-035a4c4ba3ad9571.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
底图偏移情况总结如下：
* 百度底图，最坑爹的，bd-09坐标，二次加偏。
* 高德，谷歌底图，GCJ-02坐标，俗称的“火星坐标系”。
* 天地图，osm底图，通常认为是不偏移底图。
# 二 解决方案与存在问题
## 2.1 解决方案
由于底图是不可改变的，唯一能解决叠加偏移问题的方法是：**将自己的业务数据根据一定的偏移公式转换，从而使数据的坐标与底图达到相对对齐**。当前主流编程语言，都有类似处理坐标偏移的公式换算库，满足不同语言开发的GIS项目需求。比如如下几个地址：
https://github.com/FreeGIS/CoordinateTransform
https://github.com/wandergis/coordtransform
## 2.2 存在问题
* 不支持批量计算。
当前各种坐标转换库，都是实现单个点坐标转到底图对应的坐标。但实际上，GIS存在 **图形复杂**，**数据量大**的通用特征，每个图层都有大量图形记录，每个图形记录，其图形常用分类就有点线面多点多线多面等六种，每个图形都可能由非常多的坐标点组成。业务需求最好是支持批量计算。
* 动态计算，显示效率低。
当前各种坐标转换库，都是基于前后台的语言实现的，每次都要获取数据源数据，再通过实时计算展示，当数据复杂，数据量大时候，效率很成问题。解决办法通常是，后台先读取数据源，然后计算好，最后将计算结果重新存入库里，项目使用时，直接读取计算好的结果。  捯饬的费劲不？
* 数据转换服务维护复杂。
当数据库数据发生变更时，转换服务要能增量得到变更的数据，然后计算，然后再更新数据库已存储的转换结果。整个架构要是能自动维护好，还是很复杂的。
# 三 PostGIS方案
基于现有方案普遍存在的问题，笔者基于最常用的开源GIS空间数据库PostGIS开发了一个function，基于一行sql搞定一切的是思想，满足使用PostGIS的开发者，简单的处理这些坐标转换问题。PostGIS实现的仓库如下：
https://github.com/FreeGIS/Postgis_Coordinate_Transform
实现功能列表如下：
* 支持WGS84与bd-09,gcj-02坐标系，百度经纬度与百度墨卡托之间互转。
* 支持点线面多点多线多面的复杂图形批量转换。
* 支持对整个表批处理转换。

约束：
* 要求转换的表是基于PostGIS创建的空间关系表
示例支持的表：
```
create table point_test(
  gid serial primary key,
  name text,
  geom geometry(Point,4326)
);
```
不支持的表：
```
create table point_test(
  gid serial primary key,
  name text,
  lon numeric,   --经度
  lat numeric     --纬度
);
```
不支持的表是普通关系表，非空间图形表。
* 要求转换的图形必须是二维图形
当前暂不支持三维或者多维，如带Z值的高程，带M值的测量值等，由于过于复杂，目前笔者暂未有时间去过多实现。
* 转换表图形坐标系必须是epsg:4326
除了将百度墨卡托坐标转百度经纬度外，其他转换方式，必须保证转换表的坐标系是4326，其他坐标系，需要用户使用ST_Transform函数，将其数据先转到4326坐标系下，再使用该工具。百度墨卡托坐标转百度经纬度转换，数据源必须是3857的。
* 图形数据是点线面多点多线多面
仅仅支持Point,LineString,Polygon,MultiPoint,MultiLineString,MultiPolygon六种明确类型。其他的PostGIS类型由于不常用，且不严格规范，通常不用于标准的空间数据库类型，暂时不考虑实现。

## 3.1 安装应用
前提：PostGIS用户，图形表是基于PostGIS的空间关系表。
示例：在test库安装转换方法
```
[postgres@sss~]$ psql -d test
psql (11.1)
Type "help" for help.

test=# \i FreeGIS_Coordinate_Transform.sql
CREATE FUNCTION
CREATE FUNCTION
CREATE FUNCTION
CREATE FUNCTION
CREATE FUNCTION
CREATE FUNCTION
CREATE FUNCTION
CREATE FUNCTION
CREATE TYPE
CREATE FUNCTION
```
方法简介：
```
FreeGIS_Coordinate_Transform(
	in schema_name text,
	in table_name text,
	in transform_type FreeGIS_coordinate_transform_type
)
```
schema_name:表的schema名称。
table_name：表的名称。
transform_type：转换类型，枚举型，类型如下：

 BD2GCJ：百度经纬度 转 火星经纬度。
GCJ2BD：火星经纬度 转 百度经纬度。
WGS2GCJ：WGS84经纬度 转 火星经纬度
GCJ2WGS：火星经纬度 转 WGS84经纬度。
BD2WGS：百度经纬度 转 WGS84经纬度。
WGS2BD：WGS84经纬度 转 百度经纬度。
BDWGS2BDMKT：百度经纬度 转 百度墨卡托。
BDMKT2BDWGS：百度墨卡托 转 百度经纬度。
WGS2BDMKT： WGS84经纬度 转 百度墨卡托。
BDMKT2WGS：百度墨卡托 转 WGS84经纬度。
转换批处理执行：
```
--将public.test表从wgs84坐标转火星坐标。
select FreeGIS_Coordinate_Transform('public','test','WGS2GCJ');
```
执行后，test表新增了一个transform_geom字段，就是转换后的结果。
![转换结果](https://upload-images.jianshu.io/upload_images/68979-1a93d84bca1ee81a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



## 3.2 底图叠加示例
### 3.2.1 叠加osm，天地图底图
  企业的坐标，可不做处理，直接叠加。
![点叠加osm](https://upload-images.jianshu.io/upload_images/68979-d93c59f6351cbb26.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

### 3.2.2 叠加谷歌，高德底图
将企业的数据，使用wgs84转火星坐标，然后叠加：
```
select FreeGIS_Coordinate_Transform('public','test_pt','WGS2GCJ');
```
执行展示：
```
--transform_geom字段存储了转换结果，示例使用如下：
create or replace view v_test_pt as select gid,name,transform_geom as geom from test_pt;
```
将v_test_pt 发布成地理服务后，叠加地图如下：
![转换后叠加osm，发生偏移](https://upload-images.jianshu.io/upload_images/68979-328fef4986f30587.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
![转换后叠加谷歌或高德，位置匹配](https://upload-images.jianshu.io/upload_images/68979-dfc63376fcaa3810.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

依次制作了测试线和面，测试情况如下
![线 osm](https://upload-images.jianshu.io/upload_images/68979-d3f0ad4f504f01f0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
![线 谷歌](https://upload-images.jianshu.io/upload_images/68979-4dba0ec249e10264.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![面 osm](https://upload-images.jianshu.io/upload_images/68979-6767b5ad65a74e8a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
![面 谷歌](https://upload-images.jianshu.io/upload_images/68979-a0d1fd7ad70ae5f7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

### 3.2.3 叠加百度底图
将企业的数据，使用wgs84转百度墨卡托坐标，然后叠加：
```
select FreeGIS_Coordinate_Transform('public','test_pg','WGS2BDMKT');
```
![面 百度](https://upload-images.jianshu.io/upload_images/68979-701a5226f481bc63.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

说明下：将wgs批量转到百度地图上，需要先转到百度经纬，再从百度经纬转到百度墨卡托，这些步骤被WGS2BDMKT封装了。
百度很麻烦很麻烦！！！
其他底图的偏移操作是，将wgs偏移到对应的底图，然后使用标准的墨卡托投影函数叠加到底图上即可。
百度底图操作是，将wgs偏移到对应的底图，但是底图是墨卡托坐标系，百度经纬度不能使用标准的墨卡托投影函数，二次加密的，所以要写个自定义函数，将百度经纬度自己转到百度墨卡托，才能叠加到百度底图。
这是其他转换库都没注意到，没涉及到的，坑爹的百度！！！

