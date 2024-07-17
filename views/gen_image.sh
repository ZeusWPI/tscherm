#!/usr/bin/env bash
echo Showing preview...
convert -resize '640x480!' $1 png:- | feh -
convert -resize '640x480!' $1 png:- | stream -map r -storage-type char png:- $2
