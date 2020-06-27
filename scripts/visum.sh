if [ "$1" == "" ]; then
  echo "No file path provided."
  exit 1
fi


CONF_FILE="/tmp/visum.conf"
PUBLIC_IP=`curl icanhazip.com` # ~120ms delay, the fastest website.
# Some filenames contain spaces and special characters which need to be encoded (%%x)
URL_ENCODED_FILEPATH=`python3 -c "import urllib.parse; print(urllib.parse.quote('''$1'''))"`

# By default, files are opened in Microsoft Online Office
BASE_OFFICE_URL="http://view.officeapps.live.com/op/view.aspx?src="
VISUM_PREFERRED_OFFICE=`awk -F '=' '/OFFICE/{print $2}' ~/.config/visum/visum.conf`

if [ "$VISUM_PREFERRED_OFFICE" == "GOOGLE_OFFICE" ]; then
  BASE_OFFICE_URL="https://docs.google.com/viewer?url="
fi

# Check if the config file exists
if test -f "$CONF_FILE"; then
  # Get data from config file
  PORT=`awk -F '=' '/PORT/{print $2}' "$CONF_FILE"`
  REMOTE_HOST_UUID=`awk -F '=' '/REMOTE_HOST_UUID/{print $2}' "$CONF_FILE"`

  # Check if the conf data is valid
  PY_SERVER_PID=`lsof -t -i:$PORT`
  SERVEO_SSH_CONNECTION_PID=`ps aux | grep ssh | grep $PORT | awk -F " " '{print $2}'`

  # If the python server is running AND serveo is forwarding port of the python server
  if [ -n "$PY_SERVER_PID" ] && [ -n "$SERVEO_SSH_CONNECTION_PID" ]; then
    DOCUMENT_URL="${BASE_OFFICE_URL}https://$REMOTE_HOST_UUID.serveousercontent.com/$URL_ENCODED_FILEPATH?key=$PUBLIC_IP"
    x-www-browser $DOCUMENT_URL
    exit
  else
    # If something went wrong, (either SSH connection dropped) OR/AND
    # python server was shutdown (whatever the reason may be)
    # We want to kill both processes (if any) and start them again (the rest of the script below)
    kill -9 $PY_SERVER_PID
    kill -9 $SERVEO_SSH_CONNECTION_PID
  fi
fi

# Get a random available port & generate a random serveo subdomain (UUID)
REMOTE_HOST_UUID=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1`
PORT=`comm -23 <(seq 49152 65535 | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1`
DOCUMENT_URL="${BASE_OFFICE_URL}https://$REMOTE_HOST_UUID.serveousercontent.com/$URL_ENCODED_FILEPATH?key=$PUBLIC_IP"

open_document() {
  STATUS_CODE=`curl -s -o /dev/null -w "%{http_code}" https://$REMOTE_HOST_UUID.serveousercontent.com`

  # 400 indicates that port forwarding is working
  # (server returns 400 on invalid request, like in our case -> no key & file)
  while [ "$STATUS_CODE" != "400" ]
  do
    sleep 0.5
    STATUS_CODE=`curl -s -o /dev/null -w "%{http_code}" https://$REMOTE_HOST_UUID.serveousercontent.com`
  done

  x-www-browser $DOCUMENT_URL
}

# Start a local server
# Path relative from the Path value specified in the visum.desktop file
python3 scripts/server.py $PORT &

# Save configurations (used for performance optimization)
echo "PORT=$PORT" > $CONF_FILE
echo "REMOTE_HOST_UUID=$REMOTE_HOST_UUID" >> $CONF_FILE

# Check in the background for successful connection
# Once the connection is up, the document will be opened in the default browser
open_document &

# Forward the local port (python3 server) with serveo
ssh -o "StrictHostKeyChecking no" -R $REMOTE_HOST_UUID:80:localhost:$PORT serveo.net
