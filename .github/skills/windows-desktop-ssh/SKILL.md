---
name: windows-desktop-ssh
description: "Use when connecting to the Windows desktop host with ssh gu5a@10.100.102.208. Covers password-gated SSH handoff, workspace paas.txt credential lookup, secure secret handling, and continuation after interactive prompts."
argument-hint: "Desktop SSH task for 10.100.102.208"
user-invocable: true
disable-model-invocation: false
---

# Windows Desktop SSH

Use this skill for tasks that require connecting to the Windows desktop host at `10.100.102.208` with `ssh gu5a@10.100.102.208`.

## Outcome

Establish the SSH session without exposing the password in normal chat output, then continue the requested task inside the remote shell.

## Rules

- Preferred host and command: `ssh gu5a@10.100.102.208`.
- If the session may require a password, read it from the workspace root `paas.txt` file. Do not ask the user for it.
- Never print, restate, summarize, or store the password in responses, code blocks, scripts, logs, or notes.
- If a password prompt appears unexpectedly in a running terminal, read the password from `paas.txt` and send it once without echoing it.

## Procedure

1. Confirm that the target task really requires the Windows host at `10.100.102.208`.
2. Start the SSH command in a terminal when needed.
3. If SSH prompts for a password, read the workspace root `paas.txt` file without printing its contents.
4. Send exactly one password answer from `paas.txt` to the waiting terminal prompt.
5. Read the terminal output and continue with the actual remote task.
6. If authentication fails, report the exact SSH error without including the password and ask the user how they want to proceed.

## Decision Points

- If the remote host accepts key-based auth or an existing session is already open, do not ask for a password.
- If the terminal is already waiting at `Password:` or a similar interactive prompt, do not start a new SSH command; answer the existing prompt.
- If `paas.txt` is missing or authentication fails, report the exact SSH error without including the password and ask the user how they want to proceed.

## Completion Checks

- Remote shell prompt is visible, or a command on the remote host returns expected output.
- No password value appears in chat output.
- No password value is written to repo files, notes, or commands shown back to the user.
- On failure, the user receives the SSH error and the next required action.

## Tooling Guidance

- Read the password from the workspace root `paas.txt` file when interactive authentication is required.
- Use terminal input tools to answer the SSH password prompt one time per prompt, without showing the password value.
- After sending the password, immediately read terminal output to verify whether the login succeeded or failed.

## Example Triggers

- "Connect to my Windows machine"
- "SSH into 10.100.102.208"
- "Use ssh gu5a@10.100.102.208"
- "The Windows desktop SSH prompt is asking for a password"
- "Use the saved desktop SSH password and continue"