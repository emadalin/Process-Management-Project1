#!/bin/sh
# Deletes the two output files so the workflow can start fresh.
# Only these two files: nothing else in output/ (or anywhere) is touched.

# Work from project4/, wherever this script is run from.
cd "$(dirname "$0")" || exit 1

rm -f output/people.csv output/people.json
echo "Reset: removed output/people.csv and output/people.json"
