#!/usr/bin/python3
import requests
import time
import sys
import os
import shutil

COLLECTION_ID = "2525649339"
GAME_PATH = "/home/clague/nmrihsrv/nmrih/"
retry_time = 3
date_time = time.asctime(time.localtime(time.time()))
log = open("/home/clague/update.log", "a")

workshop_enable = False
mapcycle_enable = False

if __name__ == "__main__":
    if "-w" in sys.argv:
        workshop_enable = True

    if "-m" in sys.argv:
        mapcycle_enable = True

    if len(sys.argv) == 0 or "-a" in sys.argv:
        os.system('tmux send -t nmrih:1.1 ENTER')
        os.system('tmux send -t nmrih:1.2 ENTER')
        os.system('say 1 "服务器开始自动更新地图，可能会产生卡顿"')
        os.system('sleep 1')
        os.system('say 2 "服务器开始自动更新地图，可能会产生卡顿"')
        os.system('tmux send -t nmrih:1.1 "workshop_update" ENTER')
        os.system('tmux send -t nmrih:1.2 "workshop_update" ENTER')
        os.system('sleep 1200')
        os.system('tmux send -t nmrih:1.1 "workshop_download_collection {}" ENTER'.format(COLLECTION_ID))
        os.system('tmux send -t nmrih:1.2 "workshop_download_collection {}" ENTER'.format(COLLECTION_ID))
        os.system('sleep 2400')

        if not "-nr" in sys.argv:
            os.system('say 1 "尝试延迟退出..."')
            os.system('sleep 1')
            os.system('say 2 "尝试延迟退出..."')
            os.system('sleep 2')

            os.system('tmux send-keys -t nmrih:1.2 "sm_delay_quit" ENTER')
            os.system('tmux send-keys -t nmrih:1.1 "sm_delay_quit" ENTER')

        workshop_enable = True
        mapcycle_enable = True

map_dict = {}
collection = []

if workshop_enable:
    while retry_time > 0:
        try:
            collection = [id["publishedfileid"] for id in requests.post("https://api.steampowered.com/ISteamRemoteStorage/GetCollectionDetails/v1/", data={"collectioncount": 1, "publishedfileids[0]": COLLECTION_ID}).json()["response"]["collectiondetails"][0]["children"]]
        except:
            pass
        if len(collection) > 20:
            break
        retry_time -= 1
            
    if retry_time <= 0:
        log.write("[{}] Cannot connect to steam!\n".format(date_time))
        collection = []
    else:
        print("Connected to steam!")

with open(os.path.join(GAME_PATH, "workshop_maps.txt"), "r") as workshop_maps:
    lines = workshop_maps.readlines()

for line in lines:
    map_left = 0
    map_right = 0
    id_left = 0
    id_right = 0
    if (map_left := line.find("\"")) != -1 and (map_right := line.find("\"", map_left + 1)) != -1 and (id_left := line.find("\"", map_right + 1)) != -1 and (id_right := line.find("\"", id_left + 1)) != -1 and (not workshop_enable or line[id_left+1:id_right] in collection or collection == []):
        map_dict[line[id_left+1:id_right]] = line[map_left+1:map_right]

if workshop_enable:
    for id in collection:
        if map_dict.get(id) == None:
            log.write("[{}] Update.py -> detect workshop_maps.txt don't contain some maps, you may execute workshop_download {} first!\n".format(date_time, id))

    shutil.copyfile(os.path.join(GAME_PATH, "workshop_maps.txt"), os.path.join(GAME_PATH, "workshop_maps_bp.txt")) # backup
    workshop_maps = open(os.path.join(GAME_PATH, "workshop_maps1.txt"), "w")
    workshop_maps.write("\"WorkshopMaps\"\n{\n")

if mapcycle_enable:
    shutil.copyfile(os.path.join(GAME_PATH, "cfg/mapcycle.txt"), os.path.join(GAME_PATH, "cfg/mapcycle_bp.txt")) # backup

    with open(os.path.join(GAME_PATH, "cfg/mapcycle_bp.txt"), "r") as mapcycle_before:
        maps_before = mapcycle_before.read().splitlines();
    
    motd_edited = False;
    with open(os.path.join(GAME_PATH, "cfg/motd_text.txt"), "r") as motd:
        motd_lines = motd.readlines()
        if len(motd_lines) > 0:
            del motd_lines[-1]
    motd_lines.append("[{}]\n".format(date_time))
    motd_lines.append("新增地图：\n")

    with open(os.path.join(GAME_PATH, "cfg/mapcycle_default.txt"), "r") as mapcycle_default:
        mapcycle_default_lines = mapcycle_default.readlines()
    for line in mapcycle_default_lines:
        map_dict[line.strip()] = line.strip()

    mapcycle = open(os.path.join(GAME_PATH, "cfg/mapcycle1.txt"), "w")

map_list = []
for id, map in map_dict.items():
    if workshop_enable:
        if id.isdigit():
            workshop_maps.write("\t\"{}\"\t\t\"{}\"\n".format(map, id))
    map_list.append(map)

if mapcycle_enable:
    map_list.sort()
    for map in map_list:
        if map not in maps_before:
            motd_edited = True;
            motd_lines.append(map + "\n")
        else:
            maps_before.remove(map)
        mapcycle.write(map + "\n")

if workshop_enable:
    workshop_maps.write("}\n")
    workshop_maps.close()
    shutil.move(os.path.join(GAME_PATH, "workshop_maps1.txt"), os.path.join(GAME_PATH, "workshop_maps.txt"))
if mapcycle_enable:
    motd_lines.append("删除地图：\n")
    for map in maps_before:
        map = map.strip()
        if map:
            motd_edited = True;
            motd_lines.append(map+"\n")
    if motd_edited:
        motd_lines.append("\n本服务器部分插件源码：https://github.com/keter42/plugin-source")
        if len(motd_lines) > 40:
            motd_lines = motd_lines[-40:]
        motd = open(os.path.join(GAME_PATH, "cfg/motd_text.txt"), "w")
        motd.writelines(motd_lines);
        motd.close();
    
        motd = open(os.path.join(GAME_PATH, "cfg/motd.txt"), "w")
        motd.writelines(motd_lines);
        motd.close();
    
    shutil.move(os.path.join(GAME_PATH, "cfg/mapcycle1.txt"), os.path.join(GAME_PATH, "cfg/mapcycle.txt"))
    mapcycle.close()

log.close()

