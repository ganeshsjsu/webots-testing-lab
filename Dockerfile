# Image used by webots.cloud to run this project.
#
# The tag must match the Webots version the world was authored against
# (worlds/sw_testing_lab.wbt starts with "#VRML_SIM R2025a utf8").  Confirm the
# tag exists before publishing:
#
#     docker pull cyberbotics/webots:R2025a
#
# If your Webots version differs, change BOTH this tag and the world header.
# Deleting this file is also valid: webots.cloud then uses its own default
# image, which is sufficient because this project needs no extra packages -
# the controllers use only the Python standard library and the Webots API.
FROM cyberbotics/webots:R2025a
