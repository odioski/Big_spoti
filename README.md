Big_Spoti:

Zenity enabled wrapper for Spotify_dl.


## Installation

1. Grab Zenity;
    ```

    sudo apt install Zenity

    ```

2. Get spotify_dl and ffmpeg if you don't already have those:
    ```

    pip install --upgrade spotify_dl ffmpeg

    ``` 

3. You'll need these for extended features:
    ```

    sudo apt satisfy genisoimage core-utils cifs-utils openssh-client sshfs


    ```

4. Create SPOTIPY Credentials:
    ```

    echo  -e "SPOTIPY_CLIENT_ID=your_spotify_client_id\nSPOTIPY_CLIENT_SECRET=your_spotify_client_secret" > SPOTIPY

    chmod +x SPOTIPY

    ```

5.  Run Big_Spoti:
    ```

    ./big_spoti.sh

    ```

## Features
- Handles loading .SPOTIPY
- Creates your output directory (local, SMB, or SSH)
- Loads playlists URL's (space seperated)
- Create and launch SPOTIFY_DL_COMMAND (ie, spotify_dl -l https://open.spotify.com/playlist/######, https://open.spotify.com/plalist/#######, ..., -w -s y -k)
- Create iso of downloaded mp3's per playlist
- Copy mp3's, iso's, or both to destinations
- Clean or clear output directory and it's contents.

