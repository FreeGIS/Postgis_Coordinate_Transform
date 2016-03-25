-- 百度坐标系 (BD-09) 与 火星坐标系 (GCJ-02)的转换
-- 即 百度 转 谷歌、高德
CREATE OR REPLACE FUNCTION BD2GCJ(
	in bd_lon double precision,
	in bd_lat double precision,
	out lon double precision,
	out lat double precision
) RETURNS SETOF record As
$BODY$
DECLARE
	x double precision;
	y double precision;
	z double precision;
	theta double precision;
	x_pi double precision:=3.14159265358979324 * 3000.0 / 180.0;
BEGIN
    x:= bd_lon - 0.0065;
    y:= bd_lat - 0.006;
    z:=sqrt(power(x,2) + power(y,2)) - 0.00002 *sin(y * x_pi);
    theta:= atan2(y, x) - 0.000003 * cos(x * x_pi);
    lon:= z *cos(theta);
    lat:= z *sin(theta);
	return next;
	return;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;


--火星坐标系 (GCJ-02) 与百度坐标系 (BD-09) 的转换
--即谷歌、高德 转 百度
CREATE OR REPLACE FUNCTION GCJ2BD(
	in gj_lon double precision,
	in gj_lat double precision,
	out lon double precision,
	out lat double precision
) RETURNS SETOF record As
$BODY$
DECLARE
	z double precision;
	theta double precision;
	x_pi double precision:=3.14159265358979324 * 3000.0 / 180.0;
BEGIN
	z:= sqrt(power(gj_lon,2) + power(gj_lat,2)) + 0.00002 * sin(gj_lat * x_pi);
    theta:= atan2(gj_lat, gj_lon) + 0.000003 * cos(gj_lon * x_pi);
    lon:= z * cos(theta) + 0.0065;
    lat:= z * sin(theta) + 0.006;
	return next;
	return;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;



--84转火星
--即真实的gps坐标 转 谷歌，高德
CREATE OR REPLACE FUNCTION WGS2GCJ(
	in wgs_lon double precision,
	in wgs_lat double precision,
	out lon double precision,
	out lat double precision
) RETURNS SETOF record As
$BODY$
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
BEGIN
	--坐标在国外
	if(wgs_lon < 72.004 or wgs_lon > 137.8347 or wgs_lat < 0.8293 or wgs_lat > 55.8271) then
        lon:= wgs_lon;
		lat:= wgs_lat;
		return next;
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

    lon:= wgs_lon + dLon;
    lat:= wgs_lat + dLat;
	return next;
	return;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;


--火星转84
--即  谷歌，高德 转 真实gps坐标
CREATE OR REPLACE FUNCTION GCJ2WGS(
	in gcj_lon double precision,
	in gcj_lat double precision,
	out lon double precision,
	out lat double precision
) RETURNS SETOF record As
$BODY$
DECLARE
	rec record;
	d_lon double precision;
	d_lat double precision;
BEGIN
	select * from WGS2GCJ(gcj_lon, gcj_lat) into rec;       
    d_lon:= rec.lon - gcj_lon;
    d_lat:= rec.lat - gcj_lat;
    lon:= gcj_lon - d_lon;
    lat:= gcj_lat - d_lat;
    return next;
	return;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;



--百度转WGS
CREATE OR REPLACE FUNCTION BD2WGS(
	in bd_lon double precision,
	in bd_lat double precision,
	out lon double precision,
	out lat double precision
) RETURNS SETOF record As
$BODY$
DECLARE
	rec record;
	d_lon double precision;
	d_lat double precision;
BEGIN
	--百度先转火星，火星转84
	select * from BD2GCJ(bd_lon, bd_lat) into rec; 
	--火星转84
	select * from GCJ2WGS(rec.lon, rec.lat) into rec;  
	lon:=rec.lon;
	lat:=rec.lat;
    return next;
	return;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;

--WGS转百度
CREATE OR REPLACE FUNCTION WGS2BD(
	in wgs_lon double precision,
	in wgs_lat double precision,
	out lon double precision,
	out lat double precision
) RETURNS SETOF record As
$BODY$
DECLARE
	rec record;
	d_lon double precision;
	d_lat double precision;
BEGIN
	--84转火星
	select * from WGS2GCJ(wgs_lon, wgs_lat) into rec; 
	--火星转百度
	select * from GCJ2BD(rec.lon, rec.lat) into rec;  
	lon:=rec.lon;
	lat:=rec.lat;
    return next;
	return;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;


CREATE TYPE transform_type AS ENUM ('BD2GCJ', 'GCJ2BD', 'WGS2GCJ','GCJ2WGS','BD2WGS','WGS2BD');





--gis图层批量转换
CREATE OR REPLACE FUNCTION LayerTransform(
	in inputlayer text,--输入图层名字
	in transformtype transform_type--转换类型枚举型。
) RETURNS void As
$BODY$
DECLARE
	rec record;
	current_srid int;
	geometry_type text;
	geom_name text;
	geomrec record;
	tempgeom geometry;
	pointrec record;
	constructor text;
	beforepath int;
	beforepath2 int;
BEGIN
	execute 'select * from geometry_columns where f_table_name=$1' using inputlayer into rec;
	current_srid:=rec.srid;
	geometry_type:=rec.type;
	geom_name:=rec.f_geometry_column;
	for rec in execute 'select gid,'||geom_name||' as geom from '||inputlayer loop
		constructor:=''; 
		beforepath:=0;
		beforepath2:=0;
		if(current_srid!=4326) then--统一转到4326进行加偏或纠偏
			tempgeom:=ST_Transform(rec.geom,4326);
		else
			tempgeom:=rec.geom;
		end if;
		for geomrec in select path,geom from ST_DumpPoints(tempgeom) loop
			case transformtype
				when 'BD2GCJ' then 
					select * from BD2GCJ(st_x(geomrec.geom),st_y(geomrec.geom)) into pointrec;
				when 'GCJ2BD' then 
					select * from GCJ2BD(st_x(geomrec.geom),st_y(geomrec.geom)) into pointrec;
				when 'WGS2GCJ' then 
					select * from WGS2GCJ(st_x(geomrec.geom),st_y(geomrec.geom)) into pointrec;
				when 'GCJ2WGS' then 
					select * from GCJ2WGS(st_x(geomrec.geom),st_y(geomrec.geom)) into pointrec;
				when 'BD2WGS' then 
					select * from BD2WGS(st_x(geomrec.geom),st_y(geomrec.geom)) into pointrec;
				when 'WGS2BD' then 
					select * from WGS2BD(st_x(geomrec.geom),st_y(geomrec.geom)) into pointrec;
				else
					raise notice '非定义的转换方式！';
					return;
			end case;
			case geometry_type
				when 'POINT','MULTIPOINT','LINESTRING' then
					constructor:=constructor||pointrec.lon::text||' '||pointrec.lat::text||',';	
				when 'MULTILINESTRING','POLYGON' then
					if(geomrec.path[1]!=beforepath) then--转换多个了
						constructor:=rtrim(constructor, ',');
						constructor:=constructor||')(';
						beforepath:=geomrec.path[1];
					end if;
					constructor:=constructor||pointrec.lon::text||' '||pointrec.lat::text||',';	
				when 'MULTIPOLYGON' then
					if(geomrec.path[1]!=beforepath) then--转换多个了
						constructor:=constructor||'))((';
						beforepath:=geomrec.path[1];
						beforepath2:=0;
					elsif(geomrec.path[2]!=beforepath2) then
						constructor:=rtrim(constructor, ',');
						constructor:=constructor||')(';--存在bug
						beforepath2:=geomrec.path[2];
					end if;
					constructor:=constructor||pointrec.lon::text||' '||pointrec.lat::text||',';	
				else
					raise notice '不是当前支持的图形类型！';
					return;
			end case;		
		end loop;	
		constructor:=rtrim(constructor, ',');--最后的，要截取掉。
		case geometry_type
			when 'POINT','MULTIPOINT','LINESTRING' then
				constructor:=geometry_type||'('||constructor||')';
			when 'MULTILINESTRING','POLYGON' then
				constructor:=ltrim(constructor, ')');
				constructor:=geometry_type||'('||constructor||'))';
				constructor:=replace(constructor, ')(', '),(');
			when 'MULTIPOLYGON' then
				constructor:=ltrim(constructor, '))');
				constructor:=geometry_type||'('||constructor||')))';
				constructor:=replace(constructor, ')(', '),(');
				constructor:=replace(constructor, '))((', ')),((');
			else
				raise notice '当前表非空间数据表！';
				return;
		end case;
		if(current_srid!=4326) then
			tempgeom:=ST_Transform(st_geomfromtext(constructor,4326),current_srid);
		else
			tempgeom:=st_geomfromtext(constructor,4326);
		end if;
		execute 'update '||inputlayer||' set '||geom_name||'=$1 where gid=$2' using tempgeom,rec.gid;
		if(rec.gid%100=0) then
			raise notice '已成功转换数量 %',rec.gid;
		end if;
	end loop;
	raise notice '处理完成！';
	return;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;
