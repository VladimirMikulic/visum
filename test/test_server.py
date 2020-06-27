import time
import unittest
import subprocess
import http.client as http

from pathlib import Path
from urllib.request import urlopen


PORT = 8001
connection = http.HTTPConnection("localhost", PORT)
public_ip = urlopen("https://api.ipify.org").read().decode("utf8")


doc_file_path = f"{Path(__file__).parent.absolute()}/example.doc"


class ServerTests(unittest.TestCase):
    def test_request_folder(self):
        connection.request("GET", f"//home?key={public_ip}")
        res = connection.getresponse()

        self.assertEqual(res.status, 400, "Bad Request (folders not allowed)")

    def test_request_restricted_file(self):
        connection.request("GET", f"//etc/passwd?key={public_ip}")
        res = connection.getresponse()

        self.assertEqual(res.status, 400, "Bad Request (only office files allowed)")

    def test_request_authkey(self):
        connection.request("GET", f"/{doc_file_path}")
        res = connection.getresponse()

        self.assertEqual(res.status, 400, "Bad Request (auth key is required)")

        connection.request("GET", f"/{doc_file_path}?key=256.217.17.142")
        res = connection.getresponse()

        self.assertEqual(res.status, 400, "Bad Request (invalid auth key)")

    def test_request_valid_file(self):
        connection.request("GET", f"/{doc_file_path}?key={public_ip}")
        res = connection.getresponse()

        self.assertEqual(res.status, 200, "Valid Request")

    @classmethod
    def tearDownClass(cls):
        # Shutdown the server after all tests have run
        subprocess.call(f"kill -9 `lsof -t -i:{PORT}`", shell=True)


if __name__ == "__main__":
    server_script_path = f"{Path(__file__).parent.parent.absolute()}/scripts/server.py"

    # Start server for testing
    subprocess.call(f"python3 {server_script_path} {PORT} &", shell=True)
    time.sleep(2)

    unittest.main()
