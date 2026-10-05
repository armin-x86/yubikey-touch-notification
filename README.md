# yubikey-touch-notification

**macOS only.** Plays a sound and speaks a word when your YubiKey keeps waiting for a touch, so you never miss the blinking key.

It works for any YubiKey touch request that macOS logs:

- **OpenPGP** (for example SSH through `gpg-agent`, `git` commit signing, `gpg --decrypt`)
- **FIDO2 / WebAuthn** (for example `ssh` with `ed25519-sk` keys, browser security-key prompts)

By default you hear the macOS "Submarine" sound followed by a whispered "touch" once the key has blinked 3 times without a touch.

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
2. `yubikey-touch-notify` reads those lines and plays your sound and voice. yknotify repeats its line every second while the key waits. The notifier counts those lines as blinks. It alerts on blink `BLINKS_BEFORE_ALERT`, repeats every `COOLDOWN` seconds, and stops after `MAX_ALERTS`. Touch the key before that and you hear nothing.
3. A per-user LaunchAgent keeps it running. It starts at login and restarts if it ever exits.

Safety limits keep it quiet and light when something goes wrong:

- Only one alert plays at a time. Each `afplay` or `say` is killed after 10 seconds, so hung audio can never pile up.
- yknotify can get stuck reporting a touch that is long over. If it reports one for 60 seconds straight, the notifier exits and launchd restarts it with a clean state.

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
COOLDOWN=5                                       # seconds between repeated alerts
MAX_ALERTS=3                                     # most alerts per touch request
BLINKS_BEFORE_ALERT=3                            # blinks before the first alert, 1 = at once
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

### Restart after changing the script

Config edits need no restart. If you edit `~/.local/bin/yubikey-touch-notify` itself, restart the service so the running copy picks it up:

```sh
launchctl kickstart -k gui/$(id -u)/io.github.armin-x86.yubikey-touch-notification
```

Then confirm the new process started just now:

```sh
ps -axo pid,lstart,command | grep '[y]ubikey-touch-notify'
```

### Make sure only one notifier is running

If you had your own YubiKey touch script before, it may still run as a separate LaunchAgent. You then hear two alerts per touch, and changes to this project seem to have no effect. Check before and after installing:

```sh
# Every yknotify process and its parent. Expect exactly one, under yubikey-touch-notify.
ps -axo pid,ppid,lstart,command | grep '[y]knotify'

# Every loaded LaunchAgent that looks like a YubiKey notifier. Expect only
# io.github.armin-x86.yubikey-touch-notification.
launchctl list | grep -i -E 'yubi|yknotify'

# LaunchAgent files that start yknotify or a YubiKey script.
grep -l -i -E 'yubi|yknotify' ~/Library/LaunchAgents/*.plist
```

To look up what an unknown process belongs to, pass its parent PID to `ps -o pid,ppid,command -p <PPID>`.

Stop and disable any other agent so it does not come back at login:

```sh
OTHER=com.example.old-yubikey-agent   # label from launchctl list
launchctl bootout gui/$(id -u)/$OTHER
launchctl disable gui/$(id -u)/$OTHER
```

To undo that, run `launchctl enable gui/$(id -u)/$OTHER` and then `launchctl bootstrap gui/$(id -u) <path to its plist>`. You can also delete its plist from `~/Library/LaunchAgents` if you no longer need it.

## Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/armin-x86/yubikey-touch-notification/main/uninstall.sh | bash
```

Your config is kept. To remove it too, run `./uninstall.sh --purge` from a clone, or delete `~/.config/yubikey-touch-notification`.

## Troubleshooting

**No alert when the key blinks.**
The first alert comes on the 3rd blink. If you touch the key sooner, silence is expected. Set `BLINKS_BEFORE_ALERT=1` to alert at once. Otherwise check the log with `tail ~/Library/Logs/yubikey-touch-notification.log`. If nothing shows up when the key blinks, check the service status (see above).

**The key never asks for a touch.**
Your OpenPGP touch policy may be off. Check it with `ykman openpgp info`. To require a touch for SSH authentication, run `ykman openpgp keys set-touch aut on`.

**Two alerts per touch.**
Another copy of yknotify is running. It may be a manual run in a terminal or an older LaunchAgent. See [Make sure only one notifier is running](#make-sure-only-one-notifier-is-running).

**Config or script changes seem to have no effect.**
The alert you hear may come from a different notifier. Run the checks in [Make sure only one notifier is running](#make-sure-only-one-notifier-is-running).

**Endless alerts, or many `say` processes and high CPU.**
This happened with older versions when yknotify got stuck reporting a touch. Update by running the install command again. Then clear leftovers with `pkill -x say`. The log shows `restarting it` whenever the new safety limit kicks in.

**An occasional alert with no touch request.**
yknotify detects touch requests from macOS log messages. It can sometimes misread one. A macOS update could also change those messages and break detection. If that happens, check [yknotify](https://github.com/noperator/yknotify) for a fix.

## Credits

Touch detection is done by [noperator/yknotify](https://github.com/noperator/yknotify). This project does not include its code. The installer builds it from the upstream repository at a pinned commit.
