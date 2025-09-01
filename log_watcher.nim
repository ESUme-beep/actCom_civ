# this file looks through the game logs and writes tagged data to a text file
import streams, os, strutils

const FILE_PATH: string = "Lua.log"

var 
  log_stream = newFileStream(FILE_PATH, fmRead)
  log_line = ""
  map_data = @["start_padding\n"]

if not isNil(log_stream):
  var write_switch = false
  var old_line = ""
  var nothin_counter = 0
  while true:
    try:
      log_line = log_stream.readLine()
      if log_line == "":
        echo "Nothin here!"
        nothin_counter += 1
        if nothin_counter > 15:
          break
      else:
        nothin_counter = 0
      if "BEGIN_EXPORTING_MAP_DATA" in log_line:
        write_switch = true
      if write_switch:
        map_data.add(log_line)
      if "ENDING_EXPORTING_DATA" in log_line:
        break
      if old_line == log_line or old_line == "":
        echo "waitin!"
        sleep(50)
      old_line = log_line
    except IOError:
      echo "no access! retrying..."
      sleep(150)
      nothin_counter += 1
      if nothin_counter > 10:
        echo "i didnt want to read anyway!"
        break
else:
  echo "Could not open file!"

if len(map_data) > 1:
  var map_file = open("map_data.txt", fmWrite)
  defer: 
    map_file.close()
  for data_string in map_data:
    map_file.write(data_string & "\n")
