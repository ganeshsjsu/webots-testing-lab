# Do we need a Dockerfile?

Short answer: no, and this project deliberately ships without one.

webots.cloud runs a repository in a Docker image. If the repository contains a
`Dockerfile`, that image is used; otherwise webots.cloud falls back to a default
image that Cyberbotics maintains and keeps current. This project needs no extra
packages at all — the controllers use only the Python standard library and the
Webots controller API — so the default image is sufficient, and relying on it
removes a failure mode: a `Dockerfile` naming a tag that does not exist on
Docker Hub fails the build with an error that has nothing to do with your world.

Version pinning still happens, in the place that actually matters: the world
file header (`#VRML_SIM R2025a utf8`) and the R2025a `RobotWindow.js` import in
`plugins/robot_windows/test_lab/test_lab.html`. webots.cloud reads the header
and requires R2022b or newer.

## If you later want to pin the image

Confirm the tag exists first, then commit a one-line `Dockerfile`:

```bash
docker pull cyberbotics/webots:R2025a-ubuntu22.04   # check before committing
```

```dockerfile
FROM cyberbotics/webots:R2025a-ubuntu22.04
```

Cyberbotics' published tags have carried an Ubuntu suffix in the past
(`cyberbotics/webots:R2020b-rev1-ubuntu20.04`), so do not guess the format —
check Docker Hub for the tag matching your Webots version.

You would need this only if the lab grows a dependency the default image lacks,
such as a Python package used by a new controller.
