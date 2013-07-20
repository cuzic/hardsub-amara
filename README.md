rdsub-amara
=============

## Description
  hardsub amara.org's subtitles.

     1.  download amara's json files
     2.  download youtube flv's
     3.  download amara's subtitles.
     4.  hardsub downloaded movie and subtitles into mp4's

## Directory Layout:

     hardsub-amara: Top Directory
       json/         amara's json files
       srt/          amara's Japanese/English subtitles.
       ass/          subtitles which contain both subtitles.
       youtube/      downloaded youtube flv and jsons.
       hardsub/      movies with Japanese/English subtitles.

## How to Use:

    # download amara's json
    rake setup
    
    # download amara's srt and create ass
    rake download sub
    
    # download youtube flv's and hardsub them
    rake hardsub

## Requirements:
  * **ruby 2.0**
   dependent library _titlekit_ requires Ruby 2.0+

  * **youtube-dl**
   see http://rg3.github.io/youtube-dl/

  * **mencoder**
   you can download mencoder by
    sudo apt-get install mencoder
   see in detail -- http://www.mplayerhq.hu/

  * **curl**
   using _curl_ in this current version to download subtitle and jsons.
   apt-get install curl
