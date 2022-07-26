from tkinter.filedialog import askdirectory, asksaveasfilename
from tkinter import *
import ttkbootstrap as ttk
from ttkbootstrap.constants import *
from tkinter.ttk import *
import csv
from datetime import datetime as dt, timedelta
from slpp import slpp as lua
import logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger()
logger.setLevel(logging.INFO)

localNow = dt.now()

def esoWeek(d):
    while d.weekday()!=1:
        d+=timedelta(1)
    d = d.replace(hour=12, minute=00, second=00)
    return(d+timedelta(-7), d)

def getHeaderData(dataFolder, dataFile, header, server="NA", start_timestamp=0):
    data = open(dataFolder+dataFile, 'r').read()
    decodedData = lua.decode(data.partition(header)[2])
    ledgers = {}
    for guild in list(decodedData.keys()):
        t = []
        for k,v in decodedData[guild].items():
            v['transactionDatetime'] = dt.fromtimestamp(v['transactionTimestamp'])
            esoWk = esoWeek(v['transactionDatetime'])
            v['esoWeekStart'] = esoWk[0]
            v['esoWeekEnd'] = esoWk[1]
            t.append(v)
        ledgers[guild] = t
    return ledgers

def execute():
    ledgers = getHeaderData(dataFolder, r'\GuildBookkeeper.lua', '["ledger"] = ')
    for guild in ledgers.keys():
        if len(ledgers[guild]) > 0:
            fname = "\{} Guild Ledger {}.csv".format(str(guild), dt.strftime(localNow, '%Y-%m-%d'))
            cols = list(ledgers[guild][0].keys())
            with open(outFolder + fname, 'w', newline='') as f:
                w = csv.DictWriter(f, fieldnames=cols)
                w.writeheader()
                for row in ledgers[guild]:
                    w.writerow(row)
    return True
######################
### User Interface ###
######################
def selectVariablesFolder():
    global dataFolder
    dataFolder = askdirectory()
    folderText.insert(END, "{}".format(dataFolder))
    return dataFolder

def selectSaveLocation():
    global outFolder
    outFolder = askdirectory()
    saveText.insert(END, "{}".format(outFolder))
    return outFolder

def aboutWindow():
    aboutWindow = Toplevel(window)
    aboutWindow.geometry("300x150")
    aboutWindow.wm_title("About")
    aboutLabel = Label(aboutWindow, text = "About")
    aboutLabel.pack()

window = ttk.Window(themename="superhero")

window.wm_title("Guild Bookkeeper Companion App")
window.grid_rowconfigure(0, weight=1, minsize=20) #Top Buffer
window.grid_rowconfigure(2, weight=1, minsize=80) #Open Select Button Spacing
window.grid_rowconfigure(4, weight=1, minsize=20) #Break
window.grid_rowconfigure(6, weight=1, minsize=80) #Save select button spacing
window.grid_rowconfigure(8, weight=1, minsize=20) #Break
window.grid_rowconfigure(10, weight=1, minsize=80) #Execute select button spacing
window.grid_rowconfigure(11, weight=1, minsize=20) #Bottom Buffer
window.grid_columnconfigure(0, weight=1, minsize=20) #Left Buffer
window.grid_columnconfigure(12, weight=1, minsize=20) #Break
window.grid_columnconfigure(14, weight=1, minsize=20) #Right Buffer

openLabel = Label(window, text='1. Select your Elder Scrolls "SavedVariables" folder:')
openLabel.grid(row=1, column=1, sticky='W')
open_button=Button(window,text="Select", width=10, command=selectVariablesFolder, bootstyle=SECONDARY)
open_button.grid(row=2,column=1, rowspan=1, sticky='W')
folderText = Text(window, height=1, width=75, wrap='none')
folderText.grid(row=3, column=1, columnspan=11, sticky='NWSE')

saveLabel = Label(window, text='2. Select your save folder:')
saveLabel.grid(row=5, column=1, sticky='W')
save_button=Button(window,text="Select", width=10, command=selectSaveLocation, bootstyle=SECONDARY)
save_button.grid(row=6,column=1, rowspan=1, sticky='W')
saveText = Text(window, height=1, width=75, wrap='none')
saveText.grid(row=7, column=1, columnspan=11, sticky='NWSE')

executeLabel = Label(window, text='3. Execute:')
executeLabel.grid(row=9, column=1, sticky='W')
execute_button=Button(window,text="Execute", width=10, command=execute, style="Accent.TButton")
execute_button.grid(row=10,column=1, rowspan=1, sticky='W')

window.mainloop()
