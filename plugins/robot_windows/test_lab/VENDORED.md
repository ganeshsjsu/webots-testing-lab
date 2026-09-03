# Vendored Webots robot-window API

(These files live directly beside `test_lab.html`, in the same directory Webots
already serves `test_lab.css` and `test_lab.js` from, rather than in a
subdirectory — one less assumption about how the robot window is served.)

These two files are copied **byte for byte** from the Webots source tree at tag
`R2025a`:

| File | Upstream path |
|---|---|
| `RobotWindow.js` | `resources/web/wwi/RobotWindow.js` |
| `request_methods.js` | `resources/web/wwi/request_methods.js` |

Upstream: <https://github.com/cyberbotics/webots> (Apache License 2.0).

```
sha256  3fca435057c4d6b92e4a15e440e5335392a7aac6c0190cf5da7cd2abd1a3ac0a  RobotWindow.js
sha256  7172e2e8fd6b9773933675679b70677c35e0cdcf80f8949d0b7ba274a09773cb  request_methods.js
```

## Why they are here

`test_lab.html` previously imported `RobotWindow.js` over the network from
`https://cyberbotics.com/wwi/R2025a/RobotWindow.js`, which is what the Webots
sample robot windows do. That makes the lab's user interface depend on
cyberbotics.com being reachable at the moment a student opens the robot window
— a bad dependency for a classroom, where the network is the least reliable
part of the room.

Importing them from here removes that dependency. `RobotWindow.js` imports
`request_methods.js` and nothing else, so these two files are the complete
dependency closure; both are small and neither has been modified.

The decorative favicon, which was also loaded from cyberbotics.com, was removed
at the same time: on a captive-portal or otherwise broken network a hanging
image request can stall the page load, and the robot window does not need an
icon. `test_lab.html` now makes no network requests at all.

## Upgrading past R2025a

These files are pinned to the same Webots version as the world header
(`#VRML_SIM R2025a utf8`) and must be replaced together with it. To refresh:

```bash
V=R2025a   # the version you are moving to
for f in RobotWindow.js request_methods.js; do
  curl -o "$f" "https://raw.githubusercontent.com/cyberbotics/webots/$V/resources/web/wwi/$f"
done
```

Then re-run the checksums above and record the new ones here.
