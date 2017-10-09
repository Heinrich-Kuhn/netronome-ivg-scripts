#!/usr/bin/env python

#import plotly.plotly as py
#import plotly.graph_objs as go

import string
import numpy as np

# PLOTLY SIGN IN CREDENTIALS
#py.sign_in('netronome', 'hHtGeDBSS2ayTdCFTXO0')

#-FILE TO USE-#
capture  = open("/root/capture.txt", "r")

# Text processing buffers
time_plot = []
frame_size = []
pkts_rx = []
mbits_rx = []

# Calulation Variabels
data_sets_count = 0
sum_size = 0
beg_i = 0
sum_mbits = 0
sum_pkts = 0

# Data for graphing purposes
f = []
m = []
p = []

# Final data set
pkt_data = []


# Import and filter data from raw text file
next(capture)
for line in capture:
    line = line.replace(",","")
    data = line.split()
    if data[2] != '-nan' and int(data[4]) > 1000:
        time_plot.append(data[0])
        frame_size.append(data[2])
        pkts_rx.append(data[3])
        mbits_rx.append(data[4])

# Append zero values to indicate end of data set
time_plot.append(0)
frame_size.append(0)
pkts_rx.append(0)
mbits_rx.append(0)

# Framesize logic
cur_frame = frame_size[0]
pre_frame = 0


# Sum all the values for framesizes
for i in range(0, len(frame_size)):
    cur_frame = frame_size[i]
    if cur_frame == pre_frame:
        if beg_i == 0:
                beg_i = i
        sum_size += 1
    else:
        pre_frame = cur_frame
        if sum_size > 10:
                count = 0
                for x in range (beg_i, i-1):
                    sum_pkts += int(pkts_rx[x])
                    sum_mbits += int(mbits_rx[x])
                    count += 1

# Add averages to final data set and graphing lists
                pkt_data.append( [int(frame_size[beg_i]), ( sum_pkts/count),  (sum_mbits/count), count  ])
                f.append(int(frame_size[beg_i]))
                p.append(sum_pkts/count)
                m.append(sum_mbits/count)

                data_sets_count += 1
                sum_pkts = 0
                sum_mbits = 0
                sum_size = 0
                beg_i = 0
                end_i = 0

### PLOTLY ###

#trace1 = go.Scatter(
#    x=f,
#    y=p,
#    mode='lines+markers',
#    name="'Pkts/s'",
#    hoverinfo='value',
#    line=dict(
#        color = ('rgb(22, 96, 167)'),
#        shape='spline'
#    )
#)

#trace2 = go.Scatter(
#    x=f,
#    y=m,
#    mode='lines+markers',
#    name="'Mbits/s'",
#    hoverinfo='value',
#    yaxis='y2',
#    line=dict(
#        color = ('rgb(205, 12, 24)'),
#        shape='spline'
#    )
#)
#
#
#
#data = [trace1, trace2]
#
#layout = dict(
#                title = 'Netronome Performance Graph',
#                xaxis = dict(title = 'Packet Size', showticklabels=True),
#                yaxis = dict(title = 'Packets per second'),
#                yaxis2 = dict(title = 'Mbits per second', overlaying='y', side='right')
#        )

#fig = dict(data=data, layout=layout)
#url = py.plot(fig, filename='netronome')
#print(url)

#f = open("graphurl.txt","w")
#f.write("url %s" %url)
#f.close()

parsed_data = open("/root/parsed_data.txt", "w")
parsed_data.write("Framesize, \tPackets/s, \tMbits/s \n")

for i in range(0, len(f)):
	parsed_data.write(str(f[i]) + ',\t' + str(p[i]) + ',\t' + str(m[i]) + '\n')

parsed_data.close()
print("Data parse complete!")
