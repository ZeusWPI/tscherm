#!/usr/bin/env bash
echo Showing preview...
magick $1 -resize '640x480!' png:- | feh -
magick $1 -resize '640x480!' GRAY:$2
