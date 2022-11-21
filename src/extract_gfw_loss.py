#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Nov  4 13:02:06 2022

@author: freddie
"""

import ee 
import geopandas as gpd
import numpy as np
import os
from subprocess import call
import multiprocessing
from glob import glob
import pandas as pd
from shapely.geometry import box

def download_files(name):
    
    print(name)
    if not os.path.isfile(f'/home/freddie/Cloud_Free_Metrics/PA_paper/data/gfw/gee_export_proc/*{name}*') : 
            
            global shp
            shp_idx = shp[shp['NAME'] == name]
        
            # set geometry to bounding box
            geometry = [box(x1, y1, x2, y2) for x1,y1,x2,y2 in zip(shp_idx.bounds.minx, shp_idx.bounds.miny, shp_idx.bounds.maxx, shp_idx.bounds.maxy)]
            geodf = gpd.GeoDataFrame(shp_idx, geometry=geometry)
            
            g = [i for i in geodf.geometry]
            x,y = g[0].exterior.coords.xy
            cords = np.dstack((x,y)).tolist()
            
            aoi_geom=ee.Geometry.Polygon(cords)
        
            gfw = (ee.Image("UMD/hansen/global_forest_change_2021_v1_9").select('lossyear'))
            lossyear_clip = gfw.clip(aoi_geom)
        
            try : 
                outnm = f'gfw_extract_30m_{name}' 
                link = lossyear_clip.getDownloadURL({
                'scale': 30,
                'crs': 'EPSG:4326',
                'fileFormat': 'GeoTIFF',
                'region': aoi_geom,
                'filePerBand' : True,
                'name' : outnm,
                }) 
            except Exception :
                try :
                    outnm = f'gfw_extract_50m_{name}'
                    link = lossyear_clip.getDownloadURL({
                    'scale': 50,
                    'crs': 'EPSG:4326',
                    'fileFormat': 'GeoTIFF',
                    'region': aoi_geom,
                    'filePerBand' : True,
                    'name' : outnm,
                     })
                except Exception :
                    outnm = f'gfw_extract_100m_{name}'
                    link = lossyear_clip.getDownloadURL({
                    'scale': 100,
                    'crs': 'EPSG:4326',
                    'fileFormat': 'GeoTIFF',
                    'region': aoi_geom,
                    'filePerBand' : True,
                    'name' : outnm,
                        })
            
            call(f'wget -q -O /home/freddie/Cloud_Free_Metrics/PA_paper/data/gfw/gee_export_proc/{outnm} {link}', shell = True)

    return

# usage

input_file = '/home/freddie/Cloud_Free_Metrics/PA_paper/data/formatted_pa_shapefiles/combined_formatted_PAs_v1_4_nov_22.geojson'
shp = gpd.read_file(input_file)
shp['NAME'] = shp['NAME'].str.replace('/', '_').str.replace('(', '_').str.replace(')', '_').str.replace(' ', '_')
shp['NAME'] = shp['NAME'] + shp.index.astype(str)
names = shp['NAME'].unique()
len(names)
exists = glob('/home/freddie/Cloud_Free_Metrics/PA_paper/data/gfw/gee_export_proc/*')
exists = [os.path.basename(i).replace('gfw_extract_30m_', '').replace('gfw_extract_50m_', '').replace('gfw_extract_100m_', '') for i in exists]
main_list = list(set(names) - set(exists))
len(main_list)
#pool = multiprocessing.Pool()
#pool.map(download_files, main_list)
for name in main_list :
    print(name)
    download_files(name)
