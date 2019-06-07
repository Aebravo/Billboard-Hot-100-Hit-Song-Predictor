import billboard
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
# from tqdm.auto import tqdm
import time
import sys



def chart_to_list(chart):
    tracks = []
    for track in chart:
        tracks.append([track.title, track.artist, track.peakPos, track.lastPos, track.weeks, track.rank, track.isNew, chart.date, chart.name])
    return tracks
 
def save_df(dest_filepath, charts):
	chart_df = pd.DataFrame(charts, columns=['title', 'artist', 'peakPos', 'lastPos', 'weeks', 'rank', 'isNew', 'date', 'name'])
	chart_df.to_csv(dest_filepath, index=False)
	print(chart_df.tail())
	print('\n')


# dest_filepath = '/home4/krmiddlebrook/billboard_df.csv'
dest_filepath = '/Users/kaimiddlebrook/Documents/GitHub/Billboard_Hit_Prediction/billboard_df.csv'
chart = billboard.ChartData('hot-100', date='2019-01-05', timeout=10)
final_date = '1985-01-01'
charts = []

while chart.previousDate > final_date:
    print(chart.date)
    charts.extend(chart_to_list(chart))
    try:
        chart = billboard.ChartData('hot-100', chart.previousDate, timeout=10)
    except:
        print('error occured, retrying in 2 sec')
        time.sleep(2.0)
        chart = billboard.ChartData('hot-100', chart.previousDate, timeout=10)
    finally:
    	save_df(dest_filepath, charts)




# chart_df = pd.DataFrame(charts, columns=['title', 'artist', 'peakPos', 'lastPos', 'weeks', 'rank', 'isNew', 'date', 'name'])
# chart_df.to_csv(dest_filepath, index=False)
print('finished collecting billboard data!')
