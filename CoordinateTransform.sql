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

--百度经纬转百度墨卡托
CREATE OR REPLACE FUNCTION BD_WGS2MKT(
	in bd_wgslon double precision,
	in bd_wgslat double precision,
	out lon double precision,
	out lat double precision
) RETURNS SETOF record As
$BODY$
DECLARE
	LL2MC double precision[]:=array[[-0.0015702102444, 111320.7020616939, 1704480524535203, -10338987376042340, 26112667856603880, -35149669176653700, 26595700718403920, -10725012454188240, 1800819912950474, 82.5], [0.0008277824516172526, 111320.7020463578, 647795574.6671607, -4082003173.641316, 10774905663.51142, -15171875531.51559, 12053065338.62167, -5124939663.577472, 913311935.9512032, 67.5], [0.00337398766765, 111320.7020202162, 4481351.045890365, -23393751.19931662, 79682215.47186455, -115964993.2797253, 97236711.15602145, -43661946.33752821, 8477230.501135234, 52.5], [0.00220636496208, 111320.7020209128, 51751.86112841131, 3796837.749470245, 992013.7397791013, -1221952.21711287, 1340652.697009075, -620943.6990984312, 144416.9293806241, 37.5], [-0.0003441963504368392, 111320.7020576856, 278.2353980772752, 2485758.690035394, 6070.750963243378, 54821.18345352118, 9540.606633304236, -2710.55326746645, 1405.483844121726, 22.5], [-0.0003218135878613132, 111320.7020701615, 0.00369383431289, 823725.6402795718, 0.46104986909093, 2351.343141331292, 1.58060784298199, 8.77738589078284, 0.37238884252424, 7.45]];
	LLBAND integer[]:=array[75,60,45,30,15,0];
	i integer;
	cF double precision[];
	cC double precision;
BEGIN
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
	lon:= cF[1][1] + cF[1][2] * abs(bd_wgslon);
    cC:= abs(bd_wgslat) / cF[1][10];
    lat = cF[1][3] + cF[1][4] * cC + cF[1][5] * cC * cC + cF[1][6] * cC * cC * cC + cF[1][7] * cC * cC * cC * cC + cF[1][8] * cC * cC * cC * cC * cC + cF[1][9] * cC * cC * cC * cC * cC * cC;
	if lon<0 then
		lon:=-lon;
	end if;
	if lat<0 then
		lat:=-lat;
	end if;
    return next;
	return;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;

--百度墨卡托转百度经纬度
CREATE OR REPLACE FUNCTION BD_MKT2WGS(
	in mktlon double precision,
	in mktlat double precision,
	out lon double precision,
	out lat double precision
) RETURNS SETOF record As
$BODY$
DECLARE
	MCBAND double precision[]:= array[12890594.86,8362377.87,5591021,3481989.83,1678043.12,0];
	MC2LL double precision[]:= array [[1.410526172116255e-8, 0.00000898305509648872, -1.9939833816331, 200.9824383106796, -187.2403703815547, 91.6087516669843, -23.38765649603339, 2.57121317296198, -0.03801003308653, 17337981.2], [-7.435856389565537e-9, 0.000008983055097726239, -0.78625201886289, 96.32687599759846, -1.85204757529826, -59.36935905485877, 47.40033549296737, -16.50741931063887, 2.28786674699375, 10260144.86], [-3.030883460898826e-8, 0.00000898305509983578, 0.30071316287616, 59.74293618442277, 7.357984074871, -25.38371002664745, 13.45380521110908, -3.29883767235584, 0.32710905363475, 6856817.37], [-1.981981304930552e-8, 0.000008983055099779535, 0.03278182852591, 40.31678527705744, 0.65659298677277, -4.44255534477492, 0.85341911805263, 0.12923347998204, -0.04625736007561, 4482777.06], [3.09191371068437e-9, 0.000008983055096812155, 0.00006995724062, 23.10934304144901, -0.00023663490511, -0.6321817810242, -0.00663494467273, 0.03430082397953, -0.00466043876332, 2555164.4], [2.890871144776878e-9, 0.000008983055095805407, -3.068298e-8, 7.47137025468032, -0.00000353937994, -0.02145144861037, -0.00001234426596, 0.00010322952773, -0.00000323890364, 826088.5]];
	i integer;
	cF double precision[];
	cC double precision;
BEGIN
    lon = abs(mktlon);
    lat = abs(mktlat);
	for i in 1..array_length(MCBAND,1) loop
		if lat>=MCBAND[i] then
			cF = MC2LL[i:i];
			exit;
		end if;
	end loop;
	lon = cF[1][1] + cF[1][2] * abs(lon);
    cC = abs(lat) / cF[1][10];
        lat = cF[1][3] + cF[1][4] * cC + cF[1][5] * cC * cC + cF[1][6] * cC * cC * cC + cF[1][7] * cC * cC * cC * cC + cF[1][8] * cC * cC * cC * cC * cC + cF[1][9] * cC * cC * cC * cC * cC * cC;
	if lon<0 then
		lon:=-lon;
	end if;
	if lat<0 then
		lat:=-lat;
	end if;
    return next;
	return;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;





CREATE TYPE transform_type AS ENUM ('BD2GCJ', 'GCJ2BD', 'WGS2GCJ','GCJ2WGS','BD2WGS','WGS2BD','BD_WGS2MKT','BD_MKT2WGS');





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
	k int:=0;
BEGIN
	execute 'select * from geometry_columns where f_table_name=$1' using inputlayer into rec;
	current_srid:=rec.srid;
	geometry_type:=rec.type;
	geom_name:=rec.f_geometry_column;
	if current_srid!=4326 and  current_srid!=3857 and current_srid!=900913 then
		raise notice '只支持常用的WGS84(EPSG:4326)与WGS墨卡托投影(EPSG:3857)！';
		return;
	end if;
	
	for rec in execute 'select gid,'||geom_name||' as geom from '||inputlayer loop
		if(ST_IsEmpty(rec.geom)) --如果图形是空，部分用户的数据存在异常，在此判断
			continue;
		constructor:=''; 
		beforepath:=0;
		beforepath2:=0;
		for geomrec in select path,geom from ST_DumpPoints(rec.geom) loop
			case transformtype
				when 'BD2GCJ' then 
					if(current_srid=3857 or current_srid=900913) then
						select * from BD_MKT2WGS(st_x(geomrec.geom),st_y(geomrec.geom)) into pointrec;--百度墨卡托转百度经纬
						select * from BD2GCJ(pointrec.lon,pointrec.lat) into pointrec;--百度经纬转火星经纬
					else
						select * from BD2GCJ(st_x(geomrec.geom),st_y(geomrec.geom)) into pointrec;
					end if;
				when 'GCJ2BD' then 
					if(current_srid=3857 or current_srid=900913) then
						geomrec.geom:=st_transform(geomrec.geom,4326);--先转经纬度
						select * from GCJ2BD(st_x(geomrec.geom),st_y(geomrec.geom)) into pointrec;--火星经纬转百度经纬
						select * from BD_WGS2MKT(st_x(geomrec.geom),st_y(geomrec.geom)) into pointrec;--百度经纬转百度墨卡托
					else
						select * from GCJ2BD(st_x(geomrec.geom),st_y(geomrec.geom)) into pointrec;--火星经纬转百度经纬
					end if;
				when 'WGS2GCJ' then 
					if(current_srid=3857 or current_srid=900913) then
						geomrec.geom:=st_transform(geomrec.geom,4326);--先转经纬度
					end if;
					select * from WGS2GCJ(st_x(geomrec.geom),st_y(geomrec.geom)) into pointrec;
				when 'GCJ2WGS' then 
					if(current_srid=3857 or current_srid=900913) then
						geomrec.geom:=st_transform(geomrec.geom,4326);--先转经纬度
					end if;
					select * from GCJ2WGS(st_x(geomrec.geom),st_y(geomrec.geom)) into pointrec;
				when 'BD2WGS' then 
					if(current_srid=3857 or current_srid=900913) then
						select * from BD_MKT2WGS(st_x(geomrec.geom),st_y(geomrec.geom)) into pointrec;--百度墨卡托转百度经纬
						select * from BD2WGS(pointrec.lon,pointrec.lat) into pointrec;
					else
						select * from BD2WGS(st_x(geomrec.geom),st_y(geomrec.geom)) into pointrec;
					end if;
				when 'WGS2BD' then 
					--如果是墨卡托投影的
					if(current_srid=3857 or current_srid=900913) then
						geomrec.geom:=st_transform(geomrec.geom,4326);--先转经纬度
						select * from WGS2BD(st_x(geomrec.geom),st_y(geomrec.geom)) into pointrec;--转百度经纬度
						select * from BD_WGS2MKT(pointrec.lon,pointrec.lat) into pointrec;--百度经纬转百度墨卡托
					else
						select * from WGS2BD(st_x(geomrec.geom),st_y(geomrec.geom)) into pointrec;--转百度经纬度
					end if;
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
						constructor:=rtrim(constructor, ',');
						constructor:=constructor||'))((';
						beforepath:=geomrec.path[1];
						beforepath2:=0;
					elsif(beforepath2!=0 and geomrec.path[2]!=beforepath2) then
						constructor:=rtrim(constructor, ',');
						constructor:=constructor||')(';
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
			if(transformtype!='WGS2BD' and transformtype!='GCJ2BD') then 
				tempgeom:=ST_Transform(st_geomfromtext(constructor,4326),current_srid);
			else 
				tempgeom:=st_geomfromtext(constructor,current_srid);
			end if;
		else
			tempgeom:=st_geomfromtext(constructor,4326);
		end if;
		execute 'update '||inputlayer||' set '||geom_name||'=$1 where gid=$2' using tempgeom,rec.gid;
		k:=k+1;
		if(k%100=0) then
			raise notice '已成功转换数量 %',k;
		end if;
	end loop;
	raise notice '处理完成！共转换要素%个',k;
	return;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;
