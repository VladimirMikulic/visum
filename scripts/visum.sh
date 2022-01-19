# Ensure config file exists, without changing its modification time
mkdir -p ~/.config/visum/
>> ~/.config/visum/visum.conf

if [ "$1" == "" ]; then
  echo "No file path provided."
  exit 1
fi


PORT_FILE="/tmp/visum_port.txt"
LOCALHOSTRUN_URL_FILE="/tmp/visum_localhostrun.txt"
PUBLIC_IP=`curl icanhazip.com` # ~120ms delay, the fastest website.
# Some filenames contain spaces and special characters which need to be encoded (%%x)
URL_ENCODED_FILEPATH=`python3 -c "import urllib.parse; print(urllib.parse.quote('''$1'''))"`

get_remote_server_url() {
  awk -F ' ' '{print $1}' $LOCALHOSTRUN_URL_FILE | head -n 1
}

# By default, files are opened in Microsoft Online Office
BASE_OFFICE_URL="http://view.officeapps.live.com/op/view.aspx?src="
VISUM_PREFERRED_OFFICE=`awk -F '=' '/OFFICE/{print $2}' ~/.config/visum/visum.conf`

if [ "$VISUM_PREFERRED_OFFICE" == "GOOGLE_OFFICE" ]; then
  BASE_OFFICE_URL="https://docs.google.com/viewer?url="
fi

# Check if the config file exists
if test -f "$PORT_FILE"; then
  # Get port from config file
  PORT=`awk -F '=' '/PORT/{print $2}' "$PORT_FILE"`

  # Check if the conf data is valid
  PY_SERVER_PID=`lsof -t -i:$PORT`
  LOCALHOSTRUN_SSH_CONNECTION_PID=`ps aux | grep ssh | grep $PORT | awk -F " " '{print $2}'`

  # If the python server is running AND localhost.run is forwarding port of the python server
  if [ -n "$PY_SERVER_PID" ] && [ -n "$LOCALHOSTRUN_SSH_CONNECTION_PID" ]; then
    REMOTE_SERVER_URL=`get_remote_server_url`
    DOCUMENT_URL="$BASE_OFFICE_URL$REMOTE_SERVER_URL$URL_ENCODED_FILEPATH?key=$PUBLIC_IP"

    x-www-browser $DOCUMENT_URL
    exit
  else
    # If something went wrong, (either SSH connection dropped) OR/AND
    # python server was shutdown (whatever the reason may be)
    # We want to kill both processes (if any) and start them again (the rest of the script below)
    kill -9 $PY_SERVER_PID
    kill -9 $LOCALHOSTRUN_SSH_CONNECTION_PID
  fi
fi

# Get a random available port
PORT=`comm -23 <(seq 49152 65535 | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1`

open_document() {
  # Url given to us by localhost.run
  REMOTE_SERVER_URL=`get_remote_server_url`

  # Wait for localhost.run to give us URL and then open the document
  while [ "$REMOTE_SERVER_URL" == "" ]
  do
    sleep 0.5
    REMOTE_SERVER_URL=`get_remote_server_url`
  done

  # Returns firefox/google-chrome etc.
  # x-www-browser/xdg-open don't work for some unknown reason so
  # browser command need to be retrieved like this
  DEFAULT_BROWSER=`xdg-settings get default-web-browser | awk -F "." '{print $1}'`
  DOCUMENT_URL="$BASE_OFFICE_URL$REMOTE_SERVER_URL$URL_ENCODED_FILEPATH?key=$PUBLIC_IP"

  # For users using custom mimetype handler like handlr which
  # returns application in format of userapp-APP-hash.desktop (#1 Github)
  if [[ $DEFAULT_BROWSER == *"-"* ]] && [[ $DEFAULT_BROWSER != *"chrome"* ]]; then
    DEFAULT_BROWSER=`echo $DEFAULT_BROWSER | awk -F '-' '{print $2}' | tr '[:upper:]' '[:lower:]'`
  fi

  $DEFAULT_BROWSER $DOCUMENT_URL
}

# Start a local server
python3 /usr/share/visum/scripts/server.py $PORT &

# Save server's port (used for performance optimization)
echo "PORT=$PORT" > $PORT_FILE

# Check in the background for successful connection
# Once the connection is up, the document will be opened in the default browser
open_document &

# Forward the local port (python3 server) with localhost.run
ssh -o "StrictHostKeyChecking=no" -R 80:localhost:$PORT ssh.localhost.run > $LOCALHOSTRUN_URL_FILE
