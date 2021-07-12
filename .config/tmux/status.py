#!/usr/bin/env python
import psutil
import requests
from datetime import datetime
import re
import iwlib

alarm_start="#[fg=black,bg=cyan] "
alarm_end=" #[fg=white,bg=red]"

def get_clock():
    date = datetime.now().strftime("%d/%m %H:%M")
    return date

def get_cpu():
    cpu = int(psutil.cpu_percent(interval=1))
    msg = "CPU:{}%".format(cpu)
    if cpu > 70:
        msg = alarm_start + msg + alarm_end
    return msg

def get_mem():
    mem = psutil.virtual_memory()
    mem_used = int((1-(mem.available/mem.total))*100)
    msg = "MEM:{}%".format(mem_used)
    if mem_used > 75:
        msg = alarm_start + msg + alarm_end
    return msg

def get_disk():
    hdd = int(psutil.disk_usage('/').percent)
    msg = "SSD:{}%".format(hdd)
    if hdd > 70:
        msg = alarm_start + msg + alarm_end
    return msg

def get_wifi():
    iface = iwlib.get_iwconfig("wlan0")
    signal = int(100*(iface['stats']['quality']/70))
    msg = "WIFI:{}%".format(signal)
    if signal < 40:
        msg = alarm_start + msg + alarm_end
    return msg

def get_battery():
    bat = int(psutil.sensors_battery().percent)
    msg = "BAT:{}%".format(bat)
    if bat < 15:
        msg = alarm_start + msg + alarm_end
    return msg

def get_weather():
    wea = requests.get("http://wttr.in/Madrid?format=%C,%f")
    text, temp = wea.text.split(',')
    temp = int(re.findall(r'\d+', temp)[0])
    msg = "WEA:{}°({})".format(temp,text)
    if temp > 40:
        msg = alarm_start + msg + alarm_end
    return msg

print ( \
    get_weather(), \
    get_cpu(), \
    get_mem(), \
    get_disk(), \
    get_battery(), \
    get_wifi(), \
    get_clock() \
)
