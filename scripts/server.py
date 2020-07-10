import pipes
import base64
import subprocess
import http.server
import socketserver
import os.path as path

from sys import argv
from urllib.request import urlopen
from urllib.parse import urlparse, parse_qsl, urlsplit, unquote


# Machine's public IP (serves as an Auth key)
public_ip = urlopen("https://api.ipify.org").read().decode("utf8")


class HttpRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed_url = urlparse(self.path[1:])
        filepath = "/" + unquote(parsed_url.path)
        auth_key = dict(parse_qsl(parsed_url.query)).get("key", None)

        authorized_request = auth_key == public_ip and self.is_office_file(filepath)

        if not authorized_request:
            self.handle_bad_request()
            return

        self.send_response(200)
        self.end_headers()

        with open(filepath, "rb") as file:
            self.wfile.write(file.read())

    def is_office_file(self, filepath):
        command = "file " + pipes.quote(filepath)
        result = subprocess.run(command, stdout=subprocess.PIPE, shell=True).stdout
        mimetype_list = str(result).lower().split(" ")[1:]

        valid_mimetypes = ["word", "excel", "composite", "microsoft", "powerpoint"]

        for mimetype in valid_mimetypes:
            if mimetype in mimetype_list:
                return True

        return False

    def handle_bad_request(self):
        self.send_response(400)
        self.end_headers()


if len(argv) == 1:
    print("Port not specified.")
    exit(1)

# Intialize a request handler object
request_handler = HttpRequestHandler

PORT = int(argv[1])
server = socketserver.TCPServer(("", PORT), request_handler)

print("Server is running on PORT", PORT)

# Star the server
server.serve_forever()
