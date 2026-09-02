#!/usr/bin/env bash
# Environment for running Webots headlessly (CI, or an instructor's own box).
# Adjust WEBOTS_HOME if Webots is installed elsewhere.
export WEBOTS_HOME="${WEBOTS_HOME:-/opt/webots}"
export LD_LIBRARY_PATH="$WEBOTS_HOME/lib/webots:/usr/local/lib:$LD_LIBRARY_PATH"
export QT_PLUGIN_PATH="$WEBOTS_HOME/lib/webots/qt/plugins"
export QT_QPA_PLATFORM_PLUGIN_PATH="$WEBOTS_HOME/lib/webots/qt/plugins/platforms"
export PYTHONPATH="$WEBOTS_HOME/lib/controller/python:$PYTHONPATH"
export PYTHONIOENCODING=UTF-8
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export LIBGL_ALWAYS_SOFTWARE=1
