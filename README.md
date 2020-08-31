# YouTube Downloader and Trimmer
Helpful script to download a trimmed part of a youtube video.

## Pre-requisites.
This script must be run in a unix-like environment (e.g. Linux or Mac OS).
Ensure that the following are installed:
  - **Ffmpeg.**
  
    ```bash
    $ brew install ffmpeg # Installs FFMPEG.
    $ brew update && brew upgrade ffmpeg # Upgrades FFMPEG.
    ```
  - **Ffprobe.**
    
    This should come along with FFMPEG, but ensure that you can run it `$ ffprobe --help`.
  - **Youtube-dl.**
  
  ```bash
  $ brew install youtube-dl
  ```

## Usage.
Download the file `youtube_dl_trim.sh` and navigate to the directory containing it.
```
$ . youtube_dl_trim.sh
$ trim_video  # This will print out usage instructions.
```
