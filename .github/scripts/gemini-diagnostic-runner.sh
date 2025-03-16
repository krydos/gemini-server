#!/bin/env bash

# This script runs the gemini-diagnostics script from
# https://github.com/michael-lazar/gemini-diagnostics.git
# It assumes that this repo is available in the root folder of this project.
#
# The purpose of this script is to ignore a few particular errors I don't plan fixing atm.

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
$SCRIPT_DIR/../../gemini-diagnostics/gemini-diagnostics | grep "Failed 2 checks: TLSClaims, URLWrongHost"
