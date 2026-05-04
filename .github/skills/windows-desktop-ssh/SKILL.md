---
name: windows-desktop-ssh
description: "Use when connecting to the Windows desktop host with ssh gu5a@10.100.102.208, especially when SSH prompts for a password and the user wants to enter it in chat before the agent continues. Covers password-gated SSH handoff, secure secret handling, and continuation after interactive prompts."
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
- If the session may require a password, ask the user for it in chat input before continuing.
- Never print, restate, summarize, or store the password in responses, code blocks, scripts, logs, or notes.
- Never read the password from `paas.txt` or any other local plaintext file for this workflow.
- If a password prompt appears unexpectedly in a running terminal, stop task execution and collect the password from the user before sending it.

## Procedure

1. Confirm that the target task really requires the Windows host at `10.100.102.208`.
2. Start the SSH command in a terminal when needed.
3. If SSH prompts for a password, collect it from the user with the chat question UI rather than asking them to paste it into normal prose.
4. Send exactly one password answer to the waiting terminal prompt.
5. Read the terminal output and continue with the actual remote task.
6. If authentication fails, report the exact SSH error without including the password and ask for another password entry only if needed.

## Decision Points

- If the remote host accepts key-based auth or an existing session is already open, do not ask for a password.
- If the terminal is already waiting at `Password:` or a similar interactive prompt, do not start a new SSH command; answer the existing prompt.
- If the user has not supplied the password yet, do not keep retrying authentication guesses.

## Completion Checks

- Remote shell prompt is visible, or a command on the remote host returns expected output.
- No password value appears in chat output.
- No password value is written to repo files, notes, or commands shown back to the user.
- On failure, the user receives the SSH error and the next required action.

## Tooling Guidance

- Use the question UI to collect the password when interactive authentication is required.
- Use terminal input tools to answer the SSH password prompt one time per prompt.
- After sending the password, immediately read terminal output to verify whether the login succeeded or failed.

## Example Triggers

- "Connect to my Windows machine"
- "SSH into 10.100.102.208"
- "Use ssh gu5a@10.100.102.208"
- "The Windows desktop SSH prompt is asking for a password"
- "Ask me for the SSH password in chat and continue"