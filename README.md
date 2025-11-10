# Puff: MacOS Terminal Notifier For AI Agents

<p align="center">
  <img src="assets/bender.png" alt="App Icon" width="128"/>
</p>

CLI tool for your favorite AI agent to send you macOS notifications when it's task is done.
<p align="center">
<img src="assets/example.png" alt="App Icon" width="512"/>
</p>

## Install

Install via Homebrew (the tap will be auto-added):

```sh
brew install vossenwout/puff/puff
```

Homebrew keeps `puff` and `Puff.app` together under the Cellar so no extra setup is required.
## Usage

1. Enable puff notifications in macOS notification settings
2. Test it manually. From your terminal, run:
   ```sh
   puff <NameOfYourAgent>
   ```
3. Instruct your favorite cli agent (codex, claude code, cursor cli) to invoke the puff command when a task is done.

#### Example Codex-CLI 

Go to configuration file `~/.codex/config.yaml` and add the following as notify command:

```toml
notify = ["sh", "-c", "puff \"$(basename \"$PWD\")-agent\""
```

This will make codex-cli send a notification using puff when a task is done, with the agent name based on the current folder name.
## Releasing

Tag and push the new version:
```sh
git tag v0.2.0 && git push origin v0.2.0
```
Tags must be in the format `vMAJOR.MINOR.PATCH`.

## Contact

Questions, bugs, or feature ideas? Open an issue at https://github.com/vossenwout.
