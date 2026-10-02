"""Interactive integration tests; all history/databases live in temporary homes.

Run: python3 -m unittest discover -s tests -v
Requires McFly, Bash, and Zsh. No real Atuin, SSH agent, or direnv is invoked.
"""

import concurrent.futures
import fcntl
import os
from pathlib import Path
import pty
import re
import select
import shutil
import signal
import socket
import sqlite3
import struct
import subprocess
import sys
import tempfile
import termios
import time
import unittest


SOURCE = Path(__file__).resolve().parents[1]
PROMPT = b"__DOTFILES_TEST_PROMPT__ "
SHELLS = list(dict.fromkeys(filter(None, ["/bin/bash", shutil.which("bash"), shutil.which("zsh")])))


class Terminal:
    def __init__(self, shell, home, hostname="test.linkedin.biz", extra_env=None):
        env = dict(os.environ, HOME=str(home), TERM="xterm-256color",
                   DOTFILES_TEST_HOST=hostname, SSH_AUTH_SOCK=str(home / "agent.sock"))
        for key in list(env):
            if key.startswith(("MCFLY_", "ATUIN_", "XDG_")) or key in (
                "ZDOTDIR", "HISTFILE", "HISTSIZE", "HISTFILESIZE", "SHELL_SESSION_HISTORY",
                "BASH_ENV", "ENV", "TERM_SESSION_ID", "TERM_PROGRAM",
            ):
                env.pop(key, None)
        env.update(extra_env or {})
        self.output = b""
        self.shell = shell
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 120, 0, 0))
            os.chdir(home)
            args = [shell, "--noprofile", "--rcfile", str(home / ".bashrc"), "-i"]
            if Path(shell).name == "zsh":
                args = [shell, "-i"]
            os.execve(shell, args, env)
        self.wait_prompt()

    def read_until(self, marker, timeout=20):
        result = b""
        deadline = time.monotonic() + timeout
        while marker not in result:
            remaining = deadline - time.monotonic()
            if remaining <= 0 or not select.select([self.fd], [], [], remaining)[0]:
                raise AssertionError(f"Timed out waiting for {marker!r}: {result!r}")
            try:
                chunk = os.read(self.fd, 65536)
            except OSError as error:
                raise AssertionError(f"Shell exited: {result!r}") from error
            if not chunk:
                raise AssertionError(f"Shell exited: {result!r}")
            result += chunk
        self.output += result
        return result.decode(errors="replace")

    def wait_prompt(self):
        return self.read_until(PROMPT)

    def send(self, text):
        os.write(self.fd, text.encode())

    def run(self, command):
        self.send(command + "\n")
        return self.wait_prompt()

    def close(self, kill=False):
        if self.pid is None:
            return
        if kill:
            os.kill(self.pid, signal.SIGKILL)
        else:
            self.send("exit\n")
        deadline = time.monotonic() + 10
        while os.waitpid(self.pid, os.WNOHANG)[0] == 0:
            # macOS can wait for pending PTY output to be consumed on close.
            if select.select([self.fd], [], [], 0.01)[0]:
                try:
                    self.output += os.read(self.fd, 65536)
                except OSError:
                    pass
            if time.monotonic() > deadline:
                os.kill(self.pid, signal.SIGKILL)
                os.waitpid(self.pid, 0)
                os.close(self.fd)
                self.pid = None
                raise AssertionError("Shell failed to exit")
        os.close(self.fd)
        self.pid = None


@unittest.skipUnless(shutil.which("mcfly") and shutil.which("zsh"), "Requires McFly and Zsh")
class ShellHistoryTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="dotfiles-history-")
        self.home = Path(self.tmp.name).resolve()
        self.terminals = []
        self.agent = socket.socket(socket.AF_UNIX)
        self.agent.bind(str(self.home / "agent.sock"))
        config = self.home / ".config/shell"
        config.mkdir(parents=True)
        shutil.copyfile(SOURCE / "private_dot_config/shell/history.sh", config / "history.sh")
        for name in (".bashenv", ".bash-preexec.sh", ".zshenv"):
            shutil.copyfile(SOURCE / ("dot_" + name[1:]), self.home / name)
        for name in ("bash", "zsh"):
            # Function stubs take precedence even when dotfiles update PATH.
            rc = '''hostname() { printf '%s\\n' "$DOTFILES_TEST_HOST"; }
keychain() { :; }
direnv() { :; }
atuin() { printf '%s\\n' "$*" >> "$HOME/atuin-calls"; printf ':\\n'; }
_test_prompt_hook() { local code=$?; _test_prompt_status=$code; return "$code"; }
'''
            if name == "bash":
                rc += "PROMPT_COMMAND=_test_prompt_hook\n"
            else:
                rc += "precmd_functions=(_test_prompt_hook)\n"
            rc += (SOURCE / f"dot_{name}rc").read_text()
            rc += '\nPS1="__DOTFILES_TEST_PROMPT__ "\nPS2="__CONTINUATION__ "\n'
            (self.home / f".{name}rc").write_text(rc)
            (self.home / f".{name}_history").write_text(f"echo legacy-{name}\n")

    def tearDown(self):
        for terminal in self.terminals:
            terminal.close(kill=True)
        self.agent.close()
        self.tmp.cleanup()

    def terminal(self, shell, **kwargs):
        terminal = Terminal(shell, self.home, **kwargs)
        self.terminals.append(terminal)
        return terminal

    def db_rows(self):
        with sqlite3.connect(self.home / ".mcfly/history.db") as db:
            self.assertEqual(db.execute("PRAGMA integrity_check").fetchone()[0], "ok")
            return db.execute("SELECT cmd, session_id, exit_code, dir FROM commands").fetchall()

    def archives(self):
        return list((self.home / ".local/state/shell-history").glob("*.log.*"))

    def test_concurrent_terminals_and_restarts(self):
        terminals = [self.terminal(shell) for shell in SHELLS]

        def commands(pair):
            index, terminal = pair
            for number in range(15):
                terminal.run(f"echo concurrent-{index}-{number}")
            terminal.run("false")
            result = terminal.run("printf 'previous-status=%s hook-status=%s\\n' \"$?\" \"$_test_prompt_status\"")
            self.assertIn("previous-status=1 hook-status=1", result)
            terminal.run(f"printf '%s\\n' 'multiline-{index}\nsecond-line-{index}'")
            terminal.run(f"echo repeated-{index}")
            terminal.run(f"echo repeated-{index}")
            terminal.run(f" echo leading-space-{index}")
            terminal.run("pwd")
            output = terminal.run('source "$HOME/.config/shell/history.sh"; printf "reload-status=%s\\n" "$?"')
            self.assertIn("reload-status=0", output)
            terminal.run(f"echo after-reload-{index}")

        with concurrent.futures.ThreadPoolExecutor() as executor:
            list(executor.map(commands, enumerate(terminals)))
        rows = self.db_rows()
        for index, terminal in enumerate(terminals):
            expected = {f"echo concurrent-{index}-{n}" for n in range(15)}
            recorded = [row for row in rows if row[0] in expected]
            self.assertEqual({row[0] for row in recorded}, expected)
            self.assertEqual(len({row[1] for row in recorded}), 1)
            self.assertTrue(all(row[3] == str(self.home) for row in recorded))
            self.assertIn(f"printf '%s\\n' 'multiline-{index}\nsecond-line-{index}'", [row[0] for row in rows])
            self.assertNotIn(b"WARNING", terminal.output)
            self.assertNotIn(b"error:", terminal.output)

        archive_text = "\n".join(p.read_text() for p in self.archives())
        self.assertEqual(len(self.archives()), len(terminals))
        for index in range(len(terminals)):
            self.assertEqual(archive_text.count(f"repeated-{index}"), 2)
            self.assertIn(f"leading-space-{index}", archive_text)
            self.assertIn(f"multiline-{index}", archive_text)
            self.assertIn(f"second-line-{index}", archive_text)
            self.assertEqual(archive_text.count(f"after-reload-{index}"), 1)
        self.assertIn("\tpwd\n", archive_text)
        for terminal in reversed(terminals):
            terminal.close()
        # Native files also retain every session, regardless of exit order.
        for index, terminal in enumerate(terminals):
            name = Path(terminal.shell).name
            history = (self.home / f".{name}_history").read_text()
            for number in range(15):
                self.assertIn(f"concurrent-{index}-{number}", history)
            self.assertIn(f"leading-space-{index}", history)
            self.assertIn(f"second-line-{index}", history)
        restarted = self.terminal(SHELLS[-1])
        restarted.run("echo after-restart")
        self.assertTrue(any(row[0] == "echo after-restart" for row in self.db_rows()))
        self.assertFalse((self.home / "atuin-calls").exists())
        for path in self.archives() + [self.home / ".mcfly/history.db"]:
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        for name in ("bash", "zsh"):
            self.assertIn(f"legacy-{name}", (self.home / f".local/state/shell-history/{name}.before.history").read_text())

    def test_save_before_exec_and_terminal_kill(self):
        for index, shell in enumerate(SHELLS):
            terminal = self.terminal(shell)
            terminal.send(f"exec sleep 60 # killed-{index}\n")
            deadline = time.monotonic() + 5
            while not any(f"killed-{index}" in p.read_text() for p in self.archives()):
                self.assertLess(time.monotonic(), deadline)
                if select.select([terminal.fd], [], [], 0.02)[0]:
                    terminal.output += os.read(terminal.fd, 65536)
            terminal.close(kill=True)
        self.assertEqual(len(self.archives()), len(SHELLS))

    def test_ctrl_r_search_preserves_typed_query(self):
        for index, shell in enumerate(SHELLS):
            terminal = self.terminal(shell)
            terminal.run(f"echo ui-{index}-marker")
            # McFly's search excludes entries timestamped in the current second.
            time.sleep(1.1)
            terminal.send(f"echo ui-{index}\x12")
            screen = terminal.read_until(b"\x1b[?25h")
            screen = re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", screen)
            self.assertIn("McFly | ESC", screen)
            self.assertIn(f"echo ui-{index}-marker", screen)
            self.assertIn(f"$ echo ui-{index}", screen)
            terminal.send("\x1b")
            terminal.wait_prompt()
            # Clear any restored query before continuing.
            terminal.send("\x15")
            terminal.run(f"echo after-search-{index}")
            self.assertNotIn(b"error:", terminal.output)

    def test_index_failure_keeps_archive_and_native_history(self):
        for index, shell in enumerate(SHELLS):
            terminal = self.terminal(shell)
            terminal.run("MCFLY_PATH=/usr/bin/false")
            output = terminal.run(f"echo index-unavailable-{index}")
            self.assertIn("McFly indexing failed", output)
            terminal.close()
            history = (self.home / f".{Path(shell).name}_history").read_text()
            self.assertIn(f"index-unavailable-{index}", history)
            self.assertTrue(any(f"index-unavailable-{index}" in p.read_text() for p in self.archives()))

    @unittest.skipUnless(sys.platform == "darwin", "Apple Terminal is macOS-only")
    def test_apple_terminal_uses_nonexpiring_shared_history(self):
        terminal = self.terminal(shutil.which("zsh"), extra_env={
            "TERM_PROGRAM": "Apple_Terminal", "TERM_SESSION_ID": "dotfiles-test-session",
        })
        output = terminal.run('printf "history-file=%s session-history=%s\\n" "$HISTFILE" "$SHELL_SESSION_HISTORY"')
        self.assertIn(f"history-file={self.home}/.zsh_history session-history=0", output)
        terminal.run("echo apple-terminal-history")
        terminal.close()
        self.assertIn("apple-terminal-history", (self.home / ".zsh_history").read_text())

    def test_personal_host_keeps_atuin_and_no_mcfly(self):
        for shell in SHELLS:
            terminal = self.terminal(shell, hostname="personal.example.org")
            terminal.run("echo personal-native-history")
            terminal.close()
        self.assertFalse((self.home / ".mcfly").exists())
        calls = (self.home / "atuin-calls").read_text().splitlines()
        self.assertEqual(len(calls), len(SHELLS))
        self.assertEqual(set(calls), {"init bash", "init zsh"})

    def test_linkedin_com_and_no_mcfly_fallback(self):
        # Test the helper in a minimal shell PATH where McFly is unavailable.
        rc = self.home / ".zshrc"
        rc.write_text('''PATH=/usr/bin:/bin
hostname() { printf 'test.linkedin.com\\n'; }
atuin() { printf 'forbidden\\n' >> "$HOME/atuin-calls"; }
source "$HOME/.config/shell/history.sh"
PS1="__DOTFILES_TEST_PROMPT__ "
''')
        terminal = self.terminal(shutil.which("zsh"))
        terminal.run("echo fallback-without-mcfly")
        terminal.close()
        self.assertFalse((self.home / "atuin-calls").exists())
        self.assertFalse((self.home / ".mcfly").exists())
        self.assertIn("fallback-without-mcfly", (self.home / ".zsh_history").read_text())
        self.assertIn("fallback-without-mcfly", self.archives()[0].read_text())


@unittest.skipUnless(shutil.which("chezmoi") and sys.platform == "darwin", "Requires chezmoi on macOS")
class PackageSelectionTest(unittest.TestCase):
    def test_no_atuin_in_work_brewfile(self):
        template = (SOURCE / "run_onchange_darwin-install-packages.sh.tmpl").read_text()
        rendered = subprocess.run(["chezmoi", "--source", str(SOURCE), "execute-template"],
                                  input=template, text=True, capture_output=True, check=True).stdout
        for host, wanted, forbidden in [("test.linkedin.biz", "mcfly", "atuin"),
                                        ("test.linkedin.com", "mcfly", "atuin"),
                                        ("personal.example.org", "atuin", "mcfly")]:
            # Shell functions stub both commands; no real package install occurs.
            script = '''hostname() { printf '%s\\n' "$TEST_HOST"; }
brew() { /bin/cat; }
''' + rendered
            result = subprocess.run(["/bin/bash", "--noprofile", "--norc"], input=script,
                                    text=True, capture_output=True, check=True,
                                    env=dict(os.environ, TEST_HOST=host))
            self.assertIn(f'brew "{wanted}"', result.stdout)
            self.assertNotIn(f'brew "{forbidden}"', result.stdout)


if __name__ == "__main__":
    unittest.main()
