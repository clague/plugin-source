sudo schedtool -a 3 -n -10 -e sudo -u clague /home/clague/nmrihsrv/srcds_run -console -insecure -nomaster -game nmrih -nocrashdialog -port 27015 -tickrate 100 +map nmo_broadway -autoupdate -steam_dir /home/clague/.local/share/Steam/steamcmd/ -steamcmd_script /home/clague/nmrih_update.txt +servercfgfile server_test.cfg +sv_setsteamaccount EB47EFCEE59B48FF825D87C690A35A48 +sv_pure -1 -insecure -high -noipx