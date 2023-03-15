#!/usr/bin/python3

ASSET_ID = ""

# Default list. Feel free to edit.
NEVER_COLLECT  = ["\.7z$", "\.-wal$", "\.accdb$", "\.accde$", "\.accdr$", "\.accdt$", "\.accdu$", "\.asl$", "\.bin$", "\.csv$", "\.dat$", "\.db-shm$", "\.db$", "\.doc$", "\.docb$", "\.docm$", "\.docx$", "\.dot$", "\.dotm$", "\.DS_Store$", "\.emlx$", "\.img$", "\.json$", "\.key$", "\.md$", "\.mdb$", "\.mpp$", "\.msf$", "\.msg$", "\.numbers$", "\.odb$", "\.odp$", "\.ods$", "\.odt$", "\.one$", "\.oft$", "\.ost$", "\.otf$", "\.pages$", "\.pdf$", "\.plist$", "\.pot$", "\.potx$", "\.ppam$", "\.pps$", "\.ppsm$", "\.ppsx$", "\.ppt$", "\.pptm$", "\.pptx$", "\.pst$", "\.pub$", "\.rar$", "\.rtf$", "\.sldm$", "\.sldx$", "\.sqlite-journal$", "\.sqlite$", "\.swp$", "\.ttf$", "\.tracev3$", "\.txt$", "\.vcf$", "\.xla$", "\.xlam$", "\.xlm$", "\.xls$", "\.xlsb$", "\.xlsm$", "\.xlsx$", "\.xlt$", "\.xltm$", "\.xltx$", "\.xlw$", "\.wpd$", "\.xps$", "\.zip"]
ALWAYS_COLLECT = ["\.app$", "\.appx$", "\.appxbundle$", "\.bat$", "\.class$", "\.cmd$", "\.com$", "\.crx$", "\.dll$", "\.dmg$", "\.drv$", "\.dylib$", "\.ear$", "\.efi$", "\.elf$", "\.exe$", "\.hta$", "\.iso$", "\.jar$", "\.java$", "\.js$", "\.lib$", "\.lnk$", "\.msi$", "\.nar$", "\.pkg$", "\.pl$", "\.ps1$", "\.py$", "\.pyc$", "\.rb$", "\.scr$", "\.sct$", "\.sfx$", "\.sh$", "\.so$", "\.sys$", "\.vb$", "\.vba$", "\.vbs$", "\.vbscript$", "\.war$", "\.xpi$", "\.zsh"]

import os          # Used for crawling directories
import json        # JSON payloads
import subprocess  # Required to call 'file' command
import re          # Regex for extension matching
import requests    # Calling REST API
from requests.exceptions import ConnectTimeout
import sys         # Reading CLI arguments
import hashlib     # Calculating SHA256
import argparse    # CLI argument handling


 
# Create asset
def make_asset(args, asset_id):
   url = "https://app.stairwell.com/v202112/assets"
   payload = {
    "label": args.name,
    "environment_id": {"id": args.env_id}
   }
   headers = {
    "Authorization": args.api_key,
    "Content-Type": "application/json"
   }
   response = requests.request("POST", url, json=payload, headers=headers)
   if "create_time" in response.text:
      respJson = response.json()
      print("Created asset ID: " + respJson['id']['id'])
      exit(0)
   else:
      print("Error: " + response.text)
      exit(0)

def sendToStairwell(file):
   file_to_upload = open(file, "rb")
   filebytes = file_to_upload.read()
   sha256_hash = hashlib.sha256(filebytes).hexdigest()

   stage_1_payload = {
    "asset": {
      "id": ASSET_ID,
    },
    "files": [
    {
      "filePath": file,
      "expected_attributes": {
      "identifiers": [
      {
         "sha256": str(sha256_hash)
      }
        ]
      }
    }
  ]
}

   # Make the Stage 1 request
   try:
      response = requests.request("POST", 'https://http.intake.app.stairwell.com/v2021.05/upload', data=json.dumps(stage_1_payload), timeout=5)
   except ConnectTimeout:
      print('Stage 1 request has timed out')
      return
   stage_1_response = response.json()
   stage_1_action = stage_1_response['fileActions'][0]['action']
   print('Incpetion API action reponse: ' + stage_1_action)

   # Check for "UPLOAD" in the stage 1 "action" response
   if (stage_1_action == 'UPLOAD'):
      # Build payload for upload
      stage_2_payload = stage_1_response['fileActions'][0]['fields']
      stage_2_payload['file'] = filebytes

      # Stage 2 attempt upload
      upload_url = stage_1_response['fileActions'][0]['uploadUrl']
      try:
         response_2 = requests.request("POST", upload_url, files=stage_2_payload, timeout=20)
      except ConnectTimeout:
         print('Stage 2 request has timed out')
         return
    
# Upload path
def upload(args, ASSET_ID):
   if ASSET_ID == "":
      sys.exit("The ASSET_ID variable is not set, exiting...")
   print("Uploading recursively from path: " + args.path)
   for root, dirs, files in os.walk(args.path, topdown=True):
      for name in files:
         print(os.path.join(root, name))
         filePath = os.path.join(root, name)
      
         # Run 'file' command to check file type
         result = str(subprocess.run(["file", filePath], stdout=subprocess.PIPE))
      
         # Never collect extensions
         if re.search("|".join(NEVER_COLLECT), filePath):
            print("blocked extension")
      
         # Must collect extensions
         elif re.search("|".join(ALWAYS_COLLECT), filePath):
            print("allowed extension")
            sendToStairwell(filePath)
 
         # File type detected as binary by 'file' command
         elif "GNU/LINUX" in result:
            print(result)
            sendToStairwell(filePath)
            
         # File type detected as sehll script by 'file' command
         elif "shell script" in result:
            print(result)
            sendToStairwell(filePath)
            
         # Not interesting
         else:
            print("Not interesting")
            
def main():
   # create the top-level parser
   parser = argparse.ArgumentParser(prog='pyswell.py')
   subparsers = parser.add_subparsers(help='available commands')

   # By default, sub-parseres are mutually exclusive
   # Create parser for mkasset
   parser_mkasset = subparsers.add_parser('mkasset')
   parser_mkasset.add_argument('--name',
                                required=True,
                                help="Name of the asset to create")
   parser_mkasset.add_argument('--env_id',
                                required=True,
                                help="Environment ID to create the asset in")
   parser_mkasset.add_argument('--api_key',
                                required=True,
                                help="API key to create the asset with")
   parser_mkasset.set_defaults(func=make_asset)

   # Create parser for upload command
   parser_upload = subparsers.add_parser('upload')
   parser_upload.add_argument('--path',
                                   required=True,
                                   help="Path to the directory to upload")
   parser_upload.set_defaults(func=upload)

   # If no arguments have been passed, print help
   if len(sys.argv) == 1:
      parser.print_help()

   args = parser.parse_args()
   args.func(args, ASSET_ID)
            
if __name__ == "__main__":
   main()
