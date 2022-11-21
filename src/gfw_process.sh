for i in *tif ; do gdal_edit -unsetnodata $i ; done
for i in *tif ; do /bin/gdal_calc.py -A ${i} --calc=((A > 0) & (A <= 10) * 1) + ((A == 0) & (A > 10) * 0) --type Int16 --outfile Int16_2010_def_rm_${i} --co COMPRESS=DEFLATE --co TILED=YES ; done
for i in *tif ; do gdalwarp -r sum -tr 0.009 0.009 -co COMPRESS=DEFLATE -co TILED=YES -co BLOCKXSIZE=256 -co BLOCKYSIZE=256 $i sum_1km_${i} ; done
gdal_merge.py sum_1km_Int16_2010_def_rm_gfw_extract_* -o sum_1km_2010_def_gfw_gee_v1.tif
