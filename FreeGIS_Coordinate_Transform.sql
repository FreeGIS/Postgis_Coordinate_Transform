-- 百度坐标系 (BD-09) 与 火星坐标系 (GCJ-02)的转换
-- 即 百度 转 谷歌、高德
CREATE OR REPLACE FUNCTION FreeGIS_BD2GCJ(
	in bd_point geometry(Point,4326),
	out gcj_point geometry(Point,4326)
) RETURNS geometry As $BODY$
DECLARE
	x double precision;
	y double precision;
	z double precision;
	theta double precision;
	x_pi double precision:=3.14159265358979324 * 3000.0 / 180.0;
BEGIN
    x:= ST_X(bd_point) - 0.0065;
    y:= ST_Y(bd_point) - 0.006;
    z:=sqrt(power(x,2) + power(y,2)) - 0.00002 *sin(y * x_pi);
    theta:= atan2(y, x) - 0.000003 * cos(x * x_pi);
	gcj_point:=ST_SetSRID(ST_MakePoint(z *cos(theta),z *sin(theta)),4326);
	return;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;

--火星坐标系 (GCJ-02) 与百度坐标系 (BD-09) 的转换
--即谷歌、高德 转 百度
CREATE OR REPLACE FUNCTION FreeGIS_GCJ2BD(
	in gcj_point geometry(Point,4326),
	out bd_point geometry(Point,4326)
) RETURNS geometry As
$BODY$
DECLARE
	z double precision;
	theta double precision;
	x_pi double precision:=3.14159265358979324 * 3000.0 / 180.0;
	gcj_lon double precision;
	gcj_lat double precision;
BEGIN
	gcj_lon:=ST_X(gcj_point);
	gcj_lat:=ST_Y(gcj_point);
	z:= sqrt(power(gcj_lon,2) + power(gcj_lat,2)) + 0.00002 * sin(gcj_lat * x_pi);
    theta:= atan2(gcj_lat, gcj_lon) + 0.000003 * cos(gcj_lon * x_pi);
	bd_point:=ST_SetSRID(ST_MakePoint(z * cos(theta) + 0.0065,z * sin(theta) + 0.006),4326);
	return;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;



--84转火星
--即真实的gps坐标 转 谷歌，高德
CREATE OR REPLACE FUNCTION FreeGIS_WGS2GCJ(
	in wgs_point geometry(Point,4326),
	out gcj_point geometry(Point,4326)
) RETURNS geometry As $BODY$
DECLARE
    a double precision:= 6378245.0;
    ee double precision:= 0.00669342162296594323;
	dLat double precision;
	dLon double precision;
	x double precision;
	y double precision;
	radLat double precision;
	magic double precision;
	SqrtMagic double precision;
	wgs_lon double precision;
	wgs_lat double precision;
BEGIN
	wgs_lon:=ST_X(wgs_point);
	wgs_lat:=ST_Y(wgs_point);
	--坐标在国外
	if(wgs_lon < 72.004 or wgs_lon > 137.8347 or wgs_lat < 0.8293 or wgs_lat > 55.8271) then
		gcj_point:=wgs_point;
		return;
	end if;
	--国内坐标
	x:=wgs_lon - 105.0;
	y:=wgs_lat - 35.0;
	dLat:= -100.0 + 2.0 * x + 3.0 * y + 0.2 * power(y,2) + 0.1 * x * y + 0.2 * sqrt(abs(x))
			+(20.0 * sin(6.0 * x * pi()) + 20.0 * sin(2.0 * x * pi())) * 2.0 / 3.0
            + (20.0 * sin(y * pi()) + 40.0 * sin(y / 3.0 * pi())) * 2.0 / 3.0
            + (160.0 * sin(y / 12.0 * pi()) + 320 * sin(y * pi() / 30.0)) * 2.0 / 3.0;
	dLon:= 300.0 + x + 2.0 * y + 0.1 * power(x,2) + 0.1 * x * y + 0.1 * sqrt(abs(x))
            + (20.0 * sin(6.0 * x * pi()) + 20.0 * sin(2.0 * x * pi())) * 2.0 / 3.0
            + (20.0 * sin(x * pi()) + 40.0 * sin(x / 3.0 * pi())) * 2.0 / 3.0
            + (150.0 * sin(x / 12.0 * pi()) + 300.0 * sin(x / 30.0 * pi())) * 2.0 / 3.0;
	radLat:=wgs_lat / 180.0 * pi();
	magic:= sin(radLat);
	magic:=1 - ee * magic * magic;
    SqrtMagic:= sqrt(magic);

    dLon:= (dLon * 180.0) / (a / SqrtMagic * cos(radLat) * pi());
    dLat:= (dLat * 180.0) / ((a * (1 - ee)) / (magic * SqrtMagic) * pi());

	gcj_point:=ST_SetSRID(ST_MakePoint(wgs_lon + dLon,wgs_lat + dLat),4326);
	return;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;


--火星转84
--即  谷歌，高德 转 真实gps坐标
CREATE OR REPLACE FUNCTION FreeGIS_GCJ2WGS(
	in gcj_point geometry(Point,4326),
	out wgs_point geometry(Point,4326)
) RETURNS geometry As $BODY$
DECLARE
	_gcj_point geometry(Point,4326);
	
	gcj_lon double precision;
	gcj_lat double precision;
	d_lon double precision;
	d_lat double precision;
BEGIN
	_gcj_point:=WGS2GCJ(gcj_point);
	
	gcj_lon:=ST_X(gcj_point);
	gcj_lat:=ST_Y(gcj_point);
	
    d_lon:= ST_X(_gcj_point)-gcj_lon;
    d_lat:= ST_Y(_gcj_point)-gcj_lat;
	
	wgs_point:=ST_SetSRID(ST_MakePoint(gcj_lon - d_lon,gcj_lat - d_lat),4326);
	return;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;



--百度转WGS
CREATE OR REPLACE FUNCTION FreeGIS_BD2WGS(
	in bd_point geometry(Point,4326),
	out wgs_point geometry(Point,4326)
) RETURNS geometry As $BODY$
DECLARE
	_gcj_point geometry(Point,4326);
BEGIN
	--百度先转火星
	_gcj_point:=FreeGIS_BD2GCJ(bd_point);
	--火星转84
	wgs_point:=FreeGIS_GCJ2WGS(_gcj_point);
	return;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;

--WGS转百度
CREATE OR REPLACE FUNCTION FreeGIS_WGS2BD(
	in wgs_point geometry(Point,4326),
	out bd_point geometry(Point,4326)
) RETURNS geometry As $BODY$
DECLARE
	_gcj_point geometry(Point,4326);
BEGIN
	--84转火星
	_gcj_point:=FreeGIS_WGS2GCJ(wgs_point);
	--火星转百度
	bd_point:=FreeGIS_GCJ2BD(_gcj_point);
	return;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;




--百度经纬转百度墨卡托
CREATE OR REPLACE FUNCTION FreeGIS_BDWGS2BDMKT(
	in bd_point_4326 geometry(Point,4326),
	out bd_point_3857 geometry(Point,3857)
) RETURNS geometry As $BODY$
DECLARE
	LL2MC double precision[]:=array[[-0.0015702102444, 111320.7020616939, 1704480524535203, -10338987376042340, 26112667856603880, -35149669176653700, 26595700718403920, -10725012454188240, 1800819912950474, 82.5], [0.0008277824516172526, 111320.7020463578, 647795574.6671607, -4082003173.641316, 10774905663.51142, -15171875531.51559, 12053065338.62167, -5124939663.577472, 913311935.9512032, 67.5], [0.00337398766765, 111320.7020202162, 4481351.045890365, -23393751.19931662, 79682215.47186455, -115964993.2797253, 97236711.15602145, -43661946.33752821, 8477230.501135234, 52.5], [0.00220636496208, 111320.7020209128, 51751.86112841131, 3796837.749470245, 992013.7397791013, -1221952.21711287, 1340652.697009075, -620943.6990984312, 144416.9293806241, 37.5], [-0.0003441963504368392, 111320.7020576856, 278.2353980772752, 2485758.690035394, 6070.750963243378, 54821.18345352118, 9540.606633304236, -2710.55326746645, 1405.483844121726, 22.5], [-0.0003218135878613132, 111320.7020701615, 0.00369383431289, 823725.6402795718, 0.46104986909093, 2351.343141331292, 1.58060784298199, 8.77738589078284, 0.37238884252424, 7.45]];
	LLBAND integer[]:=array[75,60,45,30,15,0];
	i integer;
	cF double precision[];
	cC double precision;
	
	bd_wgslon double precision;
	bd_wgslat double precision;
	
	bd_mktlon double precision;
	bd_mktlat double precision;
BEGIN
	bd_wgslon:=ST_X(bd_point_4326);
	bd_wgslat:=ST_Y(bd_point_4326);

	while bd_wgslon > 180 loop
        bd_wgslon:= bd_wgslon-360;
    end loop;
    while bd_wgslon<-180 loop
        bd_wgslon:= bd_wgslon+360;
    end loop;
	if bd_wgslat<-74 then
		bd_wgslat:=-74;
	end if;
	if bd_wgslat>74 then
		bd_wgslat:=74;
	end if;
    for i in 1..array_length(LLBAND,1) loop
		if bd_wgslat>=LLBAND[i] then
			cF = LL2MC[i:i];
			exit;
		end if;
	end loop;
    IF array_length(cF,1) IS NULL THEN
		for i in array_length(LLBAND,1)..1 loop
			if bd_wgslat<=-LLBAND[i] then
				cF = LL2MC[i:i];
				exit;
			end if;
		end loop;
	end if;
	
	bd_mktlon:= cF[1][1] + cF[1][2] * abs(bd_wgslon);
    cC:= abs(bd_wgslat) / cF[1][10];
    bd_mktlat = cF[1][3] + cF[1][4] * cC + cF[1][5] * cC * cC + cF[1][6] * cC * cC * cC + cF[1][7] * cC * cC * cC * cC + cF[1][8] * cC * cC * cC * cC * cC + cF[1][9] * cC * cC * cC * cC * cC * cC;
	if bd_mktlon<0 then
		bd_mktlon:=-bd_mktlon;
	end if;
	if bd_mktlat<0 then
		bd_mktlat:=-bd_mktlat;
	end if;
	bd_point_3857:=ST_SetSRID(ST_MakePoint(bd_mktlon,bd_mktlat),3857);
	return;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;

--百度墨卡托转百度经纬度
CREATE OR REPLACE FUNCTION FreeGIS_BDMKT2BDWGS(
	in bd_point_3857 geometry(Point,3857),
	out bd_point_4326 geometry(Point,4326)
) RETURNS geometry As $BODY$
DECLARE
	MCBAND double precision[]:= array[12890594.86,8362377.87,5591021,3481989.83,1678043.12,0];
	MC2LL double precision[]:= array [[1.410526172116255e-8, 0.00000898305509648872, -1.9939833816331, 200.9824383106796, -187.2403703815547, 91.6087516669843, -23.38765649603339, 2.57121317296198, -0.03801003308653, 17337981.2], [-7.435856389565537e-9, 0.000008983055097726239, -0.78625201886289, 96.32687599759846, -1.85204757529826, -59.36935905485877, 47.40033549296737, -16.50741931063887, 2.28786674699375, 10260144.86], [-3.030883460898826e-8, 0.00000898305509983578, 0.30071316287616, 59.74293618442277, 7.357984074871, -25.38371002664745, 13.45380521110908, -3.29883767235584, 0.32710905363475, 6856817.37], [-1.981981304930552e-8, 0.000008983055099779535, 0.03278182852591, 40.31678527705744, 0.65659298677277, -4.44255534477492, 0.85341911805263, 0.12923347998204, -0.04625736007561, 4482777.06], [3.09191371068437e-9, 0.000008983055096812155, 0.00006995724062, 23.10934304144901, -0.00023663490511, -0.6321817810242, -0.00663494467273, 0.03430082397953, -0.00466043876332, 2555164.4], [2.890871144776878e-9, 0.000008983055095805407, -3.068298e-8, 7.47137025468032, -0.00000353937994, -0.02145144861037, -0.00001234426596, 0.00010322952773, -0.00000323890364, 826088.5]];
	i integer;
	cF double precision[];
	cC double precision;
	bd_wgslon double precision;
	bd_wgslat double precision;
	
BEGIN
    bd_wgslon = abs(ST_X(bd_point_3857));
    bd_wgslat = abs(ST_Y(bd_point_3857));
	for i in 1..array_length(MCBAND,1) loop
		if bd_wgslat>=MCBAND[i] then
			cF = MC2LL[i:i];
			exit;
		end if;
	end loop;
	bd_wgslon = cF[1][1] + cF[1][2] * abs(bd_wgslon);
    cC = abs(bd_wgslat) / cF[1][10];
        bd_wgslat = cF[1][3] + cF[1][4] * cC + cF[1][5] * cC * cC + cF[1][6] * cC * cC * cC + cF[1][7] * cC * cC * cC * cC + cF[1][8] * cC * cC * cC * cC * cC + cF[1][9] * cC * cC * cC * cC * cC * cC;
	if bd_wgslon<0 then
		bd_wgslon:=-bd_wgslon;
	end if;
	if bd_wgslat<0 then
		bd_wgslat:=-bd_wgslat;
	end if;
	bd_point_4326:=ST_SetSRID(ST_MakePoint(bd_wgslon,bd_wgslat),4326);
	return;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;

--WGS转百度墨卡托
CREATE OR REPLACE FUNCTION FreeGIS_WGS2BDMKT(
	in wgs_point geometry(Point,4326),
	out bd_point_3857 geometry(Point,3857)
) RETURNS geometry As $BODY$
DECLARE
	bd_point_4326 geometry(Point,4326);
	
BEGIN
	--wgs转百度
	bd_point_4326:=FreeGIS_WGS2BD(wgs_point);
	bd_point_3857:=FreeGIS_BDWGS2BDMKT(bd_point_4326);
	return;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;

--百度墨卡托转WGS
CREATE OR REPLACE FUNCTION FreeGIS_BDMKT2WGS(
	in bd_point_3857 geometry(Point,3857),
	out wgs_point geometry(Point,4326)
) RETURNS geometry As $BODY$
DECLARE
	bd_point_4326 geometry(Point,4326);
	
BEGIN
	--百度墨卡托转百度经纬
	bd_point_4326:=FreeGIS_BDMKT2BDWGS(bd_point_3857);
	--百度经纬转 wgs经纬
	wgs_point:=FreeGIS_BD2WGS(bd_point_4326);
	return;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;


drop TYPE if exists FreeGIS_coordinate_transform_type cascade;
CREATE TYPE FreeGIS_coordinate_transform_type AS ENUM ('BD2GCJ', 'GCJ2BD', 'WGS2GCJ','GCJ2WGS','BD2WGS','WGS2BD',
'BDWGS2BDMKT','BDMKT2BDWGS','WGS2BDMKT','BDMKT2WGS');





--对表批量进行坐标转换
CREATE OR REPLACE FUNCTION FreeGIS_Coordinate_Transform(
	in schema_name text,--转换表的schema名称
	in table_name text,--转换表名字
	in transform_type FreeGIS_coordinate_transform_type--转换类型枚举型。
) RETURNS void As
$BODY$
DECLARE
	rec record;
	geom_name text;
	geom_type text;
	transform_function_name text;
BEGIN
	--检查表是否存在
	select * from pg_tables where schemaname=schema_name and tablename=table_name into rec;
	if(rec is null) then
		raise notice '坐标转换表不存在，可能scheam或tablename输入错误！';
		return;
	end if;
	
	--检查转换表是否为空间关系表
	select * from geometry_columns where f_table_name=table_name and f_table_schema=schema_name into rec;
	if(rec is null) then
		raise notice '当前转换只支持带geometry类型的空间关系表！';
		return;
	end if;
	
	--检查图形维度，当前只支持二维。
	if(rec.coord_dimension!=2) then
		raise notice '当前转换只支持二维图形坐标！';
		return;
	end if;
	
	--检查图形坐标系，当前只支持4326坐标系（除将百度墨卡托转百度经纬度除外）
	if(transform_type!='BDMKT2BDWGS' and transform_type!='BDMKT2WGS') then
		if(rec.srid!=4326) then
			raise notice '当前转换只支持数据源为WGS84(EPSG:4326)坐标系！';
			raise notice '其他坐标系建议先自行转换到4326坐标系，然后使用该脚本进行批量坐标纠正！';
			return;
		end if;
	else
		--百度墨卡托转其他坐标系，转换方式为BD_MKT2WGS，数据源坐标系应当为3857
		if(rec.srid!=3857) then
			raise notice '百度墨卡托转其他坐标系，数据源坐标系必须为(EPSG:3857)坐标系！';
			return;
		end if;
	end if;

	geom_type:=rec.type;
	geom_name:=rec.f_geometry_column;
	
	--检查图形类型，仅仅支持Point,LineString,Polygon,MultiPoint,MultiLineString,MultiPolygon六种明确类型。
	--类似geometry或者collection类型，由于指定不明确，不太好进行规律转化。
	if(geom_type!='POINT' and geom_type!='MULTIPOINT' and geom_type!='LINESTRING' and geom_type!='MULTILINESTRING' AND 
	geom_type!='POLYGON' and geom_type!='MULTIPOLYGON') then
		raise notice '当前转换只支持Point,LineString,Polygon,MultiPoint,MultiLineString,MultiPolygon六种基本图形类型！';
		return;
	end if;
	
	--转换函数名称拼接
	transform_function_name:='FreeGIS_'||transform_type;
	
	
	--图形拆分成点，点图形 进行坐标 偏移转换。
	--转换表新建转换结果字段，对原图形字段拆分，创建临时表存储拆分结果
	if(transform_type='BDWGS2BDMKT' or transform_type='WGS2BDMKT') then
		--新增转换结果字段
		execute format('alter table %I.%I drop column if exists transform_geom',schema_name,table_name);
		execute format('alter table %I.%I add column transform_geom geometry(%s,3857)',schema_name,table_name,geom_type);
		create temp table _split_result(
			rec_ctid tid,
			geom_path integer[],
			source_geom geometry(Point,4326),
			target_geom geometry(Point,3857)
		) on commit drop;
	elsif(transform_type='BDMKT2BDWGS' or transform_type='BDMKT2WGS') then
		--新增转换结果字段
		execute format('alter table %I.%I drop column if exists transform_geom',schema_name,table_name);
		execute format('alter table %I.%I add column transform_geom geometry(%s,4326)',schema_name,table_name,geom_type);
		create temp table _split_result(
			rec_ctid tid,
			geom_path integer[],
			source_geom geometry(Point,3857),
			target_geom geometry(Point,4326)
		) on commit drop;
	else
		--新增转换结果字段
		execute format('alter table %I.%I drop column if exists transform_geom',schema_name,table_name);
		execute format('alter table %I.%I add column transform_geom geometry(%s,4326)',schema_name,table_name,geom_type);
		--新建拆分结果表
		create temp table _split_result(
			rec_ctid tid,
			geom_path integer[],
			source_geom geometry(Point,4326),
			target_geom geometry(Point,4326)
		) on commit drop;
	end if;
	
	--图形字段非空，将其拆分成点，存入临时表
	execute format('insert into _split_result(rec_ctid,geom_path,source_geom) SELECT ctid,(pt).path,(pt).geom 
	FROM (SELECT ctid, ST_DumpPoints(%I) AS pt FROM %I.%I where ST_IsEmpty(%I)=false) as dump_points',geom_name,schema_name,table_name,geom_name);
	
	
	--临时表建立索引
	create index _split_result_ctid_idx on _split_result using btree(rec_ctid);
	--批量转换，从souce源转到target记录
	execute format('update _split_result set target_geom=%s(source_geom)',transform_function_name);
	
	--转换完成后，拼装还原更改原表
	case geom_type
		when 'POINT' then
			execute format('update %I.%I t1 set transform_geom=t2.target_geom from _split_result t2 where t1.ctid=t2.rec_ctid',
			schema_name,table_name);
		when 'MULTIPOINT' then
			execute format('with _result as (select rec_ctid,ST_Multi(ST_Union(target_geom)) as geom from _split_result group by rec_ctid) 
			update %I.%I t1 set transform_geom=t2.geom from _result t2 where t1.ctid=t2.rec_ctid',
			schema_name,table_name);
		when 'LINESTRING' then
			execute format('with _result as (select rec_ctid,ST_MakeLine(target_geom) as geom from _split_result group by rec_ctid) 
			update %I.%I t1 set transform_geom=t2.geom from _result t2 where t1.ctid=t2.rec_ctid',
			schema_name,table_name);
		when 'MULTILINESTRING' then
			execute format('with _result as (select t.rec_ctid,ST_Multi(ST_Union(t.geom)) as geom from 
			(select rec_ctid,geom_path[1],ST_MakeLine(target_geom) as geom from  _split_result group by rec_ctid,geom_path[1]) t 
			group by t.rec_ctid) 
			update %I.%I t1 set transform_geom=t2.geom from _result t2 where t1.ctid=t2.rec_ctid',
			schema_name,table_name);
		when 'POLYGON' then
			execute format('with _result as (					
			with _polygon_result as (select rec_ctid,geom_path[1] as _path,ST_MakeLine(target_geom) as geom from _split_result group by rec_ctid,_path)
			select t1.rec_ctid,case when t2.geom is null then ST_MakePolygon(t1.geom) else ST_MakePolygon(t1.geom,t2.geom) end as geom 
			from (select rec_ctid,geom  from _polygon_result t where t._path=1) t1 left join 
			(select rec_ctid,array_agg(geom) as geom  from _polygon_result t where t._path!=1 group by rec_ctid) t2 on t1.rec_ctid=t2.rec_ctid) 
			update %I.%I t1 set transform_geom=t2.geom from _result t2 where t1.ctid=t2.rec_ctid',
			schema_name,table_name);
		when 'MULTIPOLYGON' then
			execute format('with _result as (
			with _Multi_Polygon_result as (
				with _polygon_result as (select rec_ctid,geom_path[1] as _path1,
				geom_path[2] as _path2,ST_MakeLine(target_geom) as geom from _split_result group by rec_ctid,_path1, _path2)
				select t1.rec_ctid,t1._path1,case when t2.geom is null then ST_MakePolygon(t1.geom) else ST_MakePolygon(t1.geom,t2.geom) end as geom 
				from (select rec_ctid,_path1,geom  from _polygon_result t where t._path2=1) t1 left join 
				(select rec_ctid,_path1,array_agg(geom) as geom  from _polygon_result t where t._path2!=1 group by rec_ctid,_path1) t2 
				on t1.rec_ctid=t2.rec_ctid
			) 
			select t.rec_ctid,ST_Multi(ST_Union(geom)) as geom from _Multi_Polygon_result t group by t.rec_ctid
			) 
			update %I.%I t1 set transform_geom=t2.geom from _result t2 where t1.ctid=t2.rec_ctid',
			schema_name,table_name);
		else
			raise notice '不是当前支持的图形类型！';
			return;
	end case;		
	return;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;