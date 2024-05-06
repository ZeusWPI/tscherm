#!/usr/bin/env bash
convert -resize '320x480!' $1 png:- | stream -map r -storage-type char png:- $2
