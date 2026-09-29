# yubikey-touch-notification

**macOS only.** Plays a sound and speaks a word whenever your YubiKey is waiting for a touch, so you never miss the blinking key.

It works for any YubiKey touch request that macOS logs:

- **OpenPGP** (for example SSH through `gpg-agent`, `git` commit signing, `gpg --decrypt`)
- **FIDO2 / WebAuthn** (for example `ssh` with `ed25519-sk` keys, browser security-key prompts)

By default you hear the macOS "Submarine" sound followed by a whispered "touch".

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/armin-x86/yubikey-touch-notification/main/install.sh | bash
```

It plays a test alert when it finishes. From then on it runs in the background and starts automatically every time you log in.

**Requirements:** macOS, and Go 1.21+ to build [yknotify](https://github.com/noperator/yknotify) once. If Go is missing, the installer installs it with Homebrew.

Prefer to read the code first? Clone the repo and run it locally:

```sh
git clone https://github.com/armin-x86/yubikey-touch-notification.git
cd yubikey-touch-notification
./install.sh
```

## How it works

```
macOS unified log ──> yknotify ──> yubikey-touch-notify ──> afplay + say
                     (detects        (reads your config,
                      touch wait)     plays the alert)
```

1. [yknotify](https://github.com/noperator/yknotify) streams the macOS system log and prints a line when a YubiKey starts waiting for a touch.
2. `yubikey-touch-notify` reads those lines and plays your sound and voice. It waits `COOLDOWN` seconds between alerts so one touch gives one alert.
3. A per-user LaunchAgent keeps it running. It starts at login and restarts if it ever exits.

No root access is needed. Everything is installed in your home folder:

| File | Purpose |
| --- | --- |
| `~/.local/bin/yknotify` | Touch detector (built from upstream, pinned commit) |
| `~/.local/bin/yubikey-touch-notify` | Plays the alert |
| `~/.config/yubikey-touch-notification/config` | Your settings |
| `~/Library/LaunchAgents/io.github.armin-x86.yubikey-touch-notification.plist` | Starts it at login and keeps it running |
| `~/Library/Logs/yubikey-touch-notification.log` | Log of detected touch requests |

## Change the sound, voice or text

Edit the config file:

```sh
open -e ~/.config/yubikey-touch-notification/config
```

```sh
SOUND="/System/Library/Sounds/Submarine.aiff"   # "" = no sound
VOICE="Whisper"                                  # "" = system default voice
TEXT="touch"                                     # "" = no speech
COOLDOWN=3                                       # seconds between alerts
```

Changes apply on the next touch request. **No restart is needed.** To hear your change right away:

```sh
~/.local/bin/yubikey-touch-notify --test
```

### Pick a sound

Listen to all built-in sounds:

```sh
for s in /System/Library/Sounds/*.aiff; do echo "$s"; afplay "$s"; sleep 0.4; done
```

You can also use your own `.aiff`, `.wav` or `.mp3` file. Use its full path.

### Pick a voice

```sh
say -v '?'                          # list all voices
say -v Samantha "touch your key"    # try one
```

Nicer "Enhanced" and "Premium" voices can be downloaded in **System Settings → Accessibility → Spoken Content → System Voice → Manage Voices**.

### Examples

```sh
# Sound only
SOUND="/System/Library/Sounds/Glass.aiff"
TEXT=""

# Voice only
SOUND=""
VOICE="Samantha"
TEXT="Touch your YubiKey"
```

## Manage the service

```sh
LABEL=io.github.armin-x86.yubikey-touch-notification

# Status (shows the PID and last exit code)
launchctl print gui/$(id -u)/$LABEL | grep -E 'state|pid|last exit'

# Restart
launchctl kickstart -k gui/$(id -u)/$LABEL

# Stop until next login
launchctl bootout gui/$(id -u)/$LABEL

# Start again
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/$LABEL.plist

# Watch detected touch requests live
tail -f ~/Library/Logs/yubikey-touch-notification.log
```

To update, run the install command again. Your config is kept.

## Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/armin-x86/yubikey-touch-notification/main/uninstall.sh | bash
```

Your config is kept. To remove it too, run `./uninstall.sh --purge` from a clone, or delete `~/.config/yubikey-touch-notification`.

## Troubleshooting

**No alert when the key blinks.**
Check the log with `tail ~/Library/Logs/yubikey-touch-notification.log`. If nothing shows up when the key blinks, check the service status (see above).

**The key never asks for a touch.**
Your OpenPGP touch policy may be off. Check it with `ykman openpgp info`. To require a touch for SSH authentication, run `ykman openpgp keys set-touch aut on`.

**Two alerts per touch.**
Another copy of yknotify is running, for example a manual run in a terminal. Find it with `pgrep -fl yknotify`.

**An occasional alert with no touch request.**
yknotify detects touch requests from macOS log messages. It can sometimes misread one. A macOS update could also change those messages and break detection. If that happens, check [yknotify](https://github.com/noperator/yknotify) for a fix.

## Credits

Touch detection is done by [noperator/yknotify](https://github.com/noperator/yknotify). This project does not include its code. The installer builds it from the upstream repository at a pinned commit.
