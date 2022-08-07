echo "Starting a Tmux session"

tmux new -d -s nmrih

tmux split-window -h -t nmrih:1
tmux split-window -h -t nmrih:1.1
tmux select-layout even-horizontal
tmux split-window -vf -t nmrih:1

tmux send -t nmrih:1.1 "sudo ./1server.sh" ENTER
tmux send -t nmrih:1.2 "sudo ./2server.sh" ENTER
tmux send -t nmrih:1.3 "sudo ./tserver.sh" ENTER

read -p "Complete creating session! Attach to the session? (Yes/no) " choose

case $choose in
	[nN][oO]|[nN])
		exit 0
		;;
	*)
		tmux a -t nmrih
		exit 0
esac
