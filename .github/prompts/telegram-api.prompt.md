---
description: "Generate Telegram bot API structures including webhook handlers, inline keyboards, command handlers, or message formatters"
name: "Telegram API Generator"
argument-hint: "webhook handlers / inline keyboards / bot commands..."
agent: "agent"
tools: [read, search]
---

Generate Telegram bot API code based on the requested structure. Follow these patterns:

## Bot Command Structure
Create clean command handlers with proper error handling and user feedback.

## Webhook Handlers
Generate secure webhook endpoints with signature verification and proper request parsing.

## Inline Keyboards
Build interactive keyboard layouts with callback handling and state management.

## Message Formatting
Create rich message templates with Telegram's formatting options (Markdown/HTML).

## Requirements
- Include proper TypeScript/Python type annotations
- Add error handling for API failures
- Implement rate limiting where appropriate
- Follow security best practices from crypto-security guidelines
- Use async/await patterns for API calls
- Include logging for debugging (without sensitive data)

## Output Format
Provide complete, production-ready code with:
- Clear function/class names
- Proper documentation/comments
- Error handling examples
- Usage examples

Focus on the most common Telegram bot patterns and make the code immediately usable.