# Code Captain

<img width="2874" height="2210" alt="image" src="https://github.com/user-attachments/assets/b7d1abb5-18d0-4c52-a427-43811ae3d540" />

A comprehensive macOS SwiftUI application that serves as a native desktop wrapper for Claude Code and other AI coding assistants.

## Features

- **Multi-Project Management**: Add and manage multiple coding projects with automatic git worktree setup
- **Session Isolation**: Each session runs in its own git branch within a dedicated workspace
- **Multi-Provider Support**: Extensible architecture supporting Claude Code, OpenCode, and future providers
- **Native macOS Inspector**: SwiftUI inspector with resizable panels for TODOs and terminal
- **Integrated Terminal**: SwiftTerm-based terminal emulation with proper keyboard input support
- **Real-time Communication**: Live bidirectional communication with CLI-based AI assistants
- **Native macOS UI**: 100% SwiftUI interface with proper macOS design patterns
- **ChatGPT-Inspired Chat**: Modern message bubbles with metadata display and real-time updates
- **Rock Solid Tool Status Management**: Step-by-step streaming with proper completion lifecycle

## Development

### Building and Running
```bash
# Build the project
xcodebuild -scheme "Code Captain" -configuration Debug build

# Build for release
xcodebuild -scheme "Code Captain" -configuration Release build

# Open in Xcode
open "Code Captain.xcodeproj"
```

### Testing
```bash
# Run all tests
xcodebuild -scheme "Code Captain" -destination "platform=macOS" test
```

## 🧪 Tool Status Management Testing

The app features a sophisticated tool status management system with step-by-step streaming completion. Here are test examples to verify the system works correctly:

### **1. File Operations Chain**
```
"Read the package.json file, then create a new file called test.md with some sample content, then list the current directory contents"
```
**Expected flow**: thinking → Read tool → thinking → Write tool → thinking → LS tool → text response

### **2. Code Analysis & Editing**
```
"Find all Swift files in the project, then read one of the main files and add a comment explaining what it does"
```
**Expected flow**: thinking → Glob tool → thinking → Read tool → thinking → Edit tool → text response

### **3. Search & Replace**
```
"Search for the word 'TODO' in all files, then show me the results and help me prioritize which ones to fix first"
```
**Expected flow**: thinking → Grep tool → thinking → text analysis response

### **4. Multiple File Operations**
```
"Create three new files: config.json, README.md, and setup.sh with appropriate starter content for each"
```
**Expected flow**: thinking → Write tool → thinking → Write tool → thinking → Write tool → text summary

### **5. Project Investigation**
```
"List the files in the project root, read the main application file, and tell me what this app does"
```
**Expected flow**: thinking → LS tool → thinking → Read tool → thinking → text explanation

### **6. Complex Analysis Chain**
```
"Find all .swift files, count how many there are, read a few key ones, and create a project structure overview"
```
**Expected flow**: thinking → Glob tool → thinking → Read tool → thinking → Read tool → thinking → Write tool → text summary

### **7. Todo Management**
```
"Create a todo list for refactoring this codebase with 5 specific tasks, prioritized by importance"
```
**Expected flow**: thinking → TodoWrite tool → text response

### **8. Code Search & Fix**
```
"Search for any hardcoded URLs in the codebase and replace them with configuration variables"
```
**Expected flow**: thinking → Grep tool → thinking → Edit/MultiEdit tools → text summary

### **9. Mixed Operations**
```
"Show me the current git status, list recent commits, and create a summary of recent changes"
```
**Expected flow**: thinking → Bash tool → thinking → Bash tool → thinking → text summary

### **10. Build & Test**
```
"Build the project and show me if there are any compilation errors or warnings"
```
**Expected flow**: thinking → Bash tool (xcodebuild) → text analysis of results

### **🚀 Advanced Stress Test**
```
"Analyze this Swift project: find all the models, read the main ones, identify any potential issues, create a refactoring todo list, and then check if there are any similar patterns in the views folder"
```
**Expected complex flow**: thinking → Glob → thinking → Read → thinking → Read → thinking → Glob → thinking → Read → thinking → TodoWrite → text

## 🎯 What to Watch For

When testing these examples, you should see:

1. ✅ **Thinking blocks complete** when the first tool starts
2. ✅ **Tool calls show specific types** (e.g., "Reading package.json..." not generic)  
3. ✅ **Tools complete properly** when their results come in
4. ✅ **New thinking blocks start** between different operations
5. ✅ **Multiple tool chains** work smoothly without interference
6. ✅ **Tool results maintain their specific type** in completed state

## Tool Status Lifecycle

The app implements a sophisticated streaming lifecycle:

- **Each new stream/step completes the previous processing step**
- **Thinking blocks complete when ANY new stream starts** 
- **Tool use blocks only complete when their tool result arrives**
- **Type changes trigger completion** of previous processing steps
- **Infinite streaming support** - works for unlimited step sequences
- **Session-level step management** - completion happens across streaming messages

## Requirements

- **macOS**: 14.0+ (macOS Sonoma)
- **Xcode**: 15.0+ with Swift 5.9+
- **Claude Code CLI**: Must be installed and accessible
- **Git**: Required for worktree functionality

## Configuration

The app expects Claude Code to be installed at one of these locations:
- `/Users/{username}/.bun/bin/claude` (Bun installation)
- `/opt/homebrew/bin/claude` (Homebrew)
- `/usr/local/bin/claude` (System)
- `/usr/bin/claude` (System)
