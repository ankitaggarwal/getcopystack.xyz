# CopyStack — Product Requirements Document

> This is the original product requirements document written before development.
> It captures the full product vision; the shipping app implements the core of it
> (sequential collection and pasting, multi-type capture, LIFO/FIFO order,
> customizable shortcut, menu bar UX). Items marked as future enhancements, and
> some of the more ambitious requirements below, are intentionally not in v1 — they
> are kept here to show the original scope and prioritization thinking.

- **Document Version:** 1.0
- **Status:** Original draft

## 1. Product Overview

### 1.1 Vision Statement
CopyStack is a specialized clipboard management tool that allows users to collect multiple copied items in sequence and paste them in a specific order. Unlike traditional clipboard managers that focus on history management, CopyStack uses a stack-based approach where items are automatically removed after pasting, enabling efficient sequential paste operations.

### 1.2 Product Objectives
- Create a seamless, efficient solution for sequential copy-paste operations
- Reduce time spent switching between applications when transferring multiple pieces of information
- Provide an intuitive, visually-oriented interface that clearly displays the paste sequence
- Support various content types (text, images, links, code snippets, etc.)
- Integrate smoothly with the macOS environment and user workflows

### 1.3 Target Users
- Knowledge workers who frequently transfer information across applications
- Developers copying code snippets from various sources
- Content creators assembling articles from research materials
- Data entry professionals entering structured information
- Administrative staff filling out forms with information from multiple sources

## 2. User Experience

### 2.1 User Personas

#### Developer
- Frequently copies code snippets from documentation, Stack Overflow, and GitHub
- Needs to maintain specific order when implementing solutions
- Works across multiple monitors and applications simultaneously

#### Content Creator
- Researches topics across multiple websites and documents
- Compiles information into coherent articles and reports
- Needs to maintain attribution and organization of source material

#### Administrative Assistant
- Fills out multiple forms with consistent information
- Copies information from databases, spreadsheets, and documents
- Must ensure accuracy when transferring data

### 2.2 Key Use Cases

1. **Assembling Code Components**
   - User researches a solution across multiple documentation pages
   - User activates CopyStack and copies snippets in sequence
   - User pastes snippets into IDE in the exact order needed

2. **Form Filling**
   - User activates CopyStack
   - User copies relevant information in sequence (name, address, phone, etc.)
   - User pastes each piece into appropriate form fields in order

3. **Content Assembly**
   - User researches a topic and finds relevant quotes/information
   - User copies each piece in a logical order
   - User pastes them into a document, adding commentary between pieces

## 3. Functional Requirements

### 3.1 Core Functionality

#### 3.1.1 Activation/Deactivation
- **FR-01:** User shall be able to activate CopyStack mode via a configurable keyboard shortcut (default: Shift+Cmd+C)
- **FR-02:** User shall be able to deactivate CopyStack mode via the same keyboard shortcut or through a UI element

#### 3.1.2 Item Collection
- **FR-04:** System shall capture all content copied to clipboard while in CopyStack mode
- **FR-05:** System shall support copying of text, formatted text, images, URLs, files, and code snippets
- **FR-06:** System shall preserve formatting and metadata of copied content
- **FR-07:** System shall visually indicate successful capture of item to stack
- **FR-08:** System shall maintain the order of items as they were copied

#### 3.1.3 Stack Management
- **FR-09:** User shall be able to view all items in current stack
- **FR-10:** User shall be able to remove items from stack via context menu
- **FR-12:** User shall be able to change stack direction (LIFO/FIFO paste order)
- **FR-14:** User shall be able to clear the entire stack with a single action

#### 3.1.4 Sequential Pasting
- **FR-15:** User shall be able to paste items sequentially using the standard paste shortcut (Cmd+V)
- **FR-16:** System shall remove item from stack once pasted
- **FR-17:** System shall visually indicate which item is next in sequence for pasting

#### 3.1.5 Integration
- **FR-20:** System shall integrate with the macOS clipboard system
- **FR-21:** System shall function across all macOS applications

### 3.2 User Interface

#### 3.2.1 Stack Display
- **FR-23:** UI shall display the stack as a floating window when active
- **FR-24:** UI shall display content previews for each item in stack
- **FR-25:** UI shall indicate item type through visual cues (icons)
- **FR-28:** UI shall display timestamps/position indicators for each item

#### 3.2.2 Feedback
- **FR-34:** System shall provide visual and audio feedback when items are added to stack
- **FR-35:** System shall provide feedback when items are pasted from stack
- **FR-36:** System shall reflect when the stack is empty after all items are pasted

### 3.3 Settings and Preferences
- **FR-37:** User shall be able to configure the activation keyboard shortcut
- **FR-39:** User shall be able to configure automatic behavior after paste
- **FR-42:** User shall be able to toggle sound effects and launch-at-login

## 4. Non-Functional Requirements

### 4.1 Performance
- **NFR-02:** System shall capture clipboard content within ~50ms of a copy operation
- **NFR-05:** System shall support stacks of at least 50 items without performance degradation
- **NFR-06:** System shall remain lightweight in memory during normal operation

### 4.2 Reliability
- **NFR-09:** System shall handle unexpected or empty clipboard data gracefully
- **NFR-10:** System shall fall back to a normal paste when the stack is empty

### 4.3 Security and Privacy
- **NFR-11:** System shall not transmit clipboard contents over the network
- **NFR-14:** System shall clear collected items when the stack window is closed

### 4.4 Compatibility
- **NFR-19:** System shall support macOS 13.0 (Ventura) and later
- **NFR-20:** System shall support Apple Silicon and Intel processors
- **NFR-22:** System shall support dark mode and light mode

## 5. Technical Approach

- Built with Swift, SwiftUI, and AppKit
- Real-time clipboard capture via `NSPasteboard` polling while the stack is open
- Global hotkeys via the Carbon Event Manager API
- Keyboard simulation (`Cmd+C` / `Cmd+V`) via `CGEvent`, requiring Accessibility permission

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the detailed design.

## 6. Future Enhancements

Explicitly out of scope for the first release:

- Drag-and-drop reordering of stack items
- Paste-all / paste-with-delay between items
- Per-application exclusions (e.g. ignore password fields)
- Persistence of the stack across restarts
- Adjustable window transparency and theming
- iOS companion app with iCloud sync
- Template system for frequently used stacks

## 7. Success Metrics

- **SM-01:** Average items collected per stack > 5
- **SM-03:** 7-day retention rate > 60%
- **SM-05:** Crash-free sessions > 99.5%
- **SM-06:** User-reported time saved > 30 minutes per week

## 8. Constraints and Assumptions

### 8.1 Constraints
- **C-01:** Must operate within the macOS security model (Accessibility permission)
- **C-02:** Must comply with Apple's Human Interface Guidelines
- **C-03:** Must not interfere with standard clipboard operations when inactive

### 8.2 Assumptions
- **A-01:** Users have basic familiarity with clipboard operations
- **A-03:** Most users will collect fewer than 20 items in a typical stack
- **A-04:** Users will primarily copy text-based content

## 9. Glossary

- **Stack:** A temporary, ordered collection of copied items
- **Stack Mode:** The state in which copied items are collected into the stack
- **Sequential Pasting:** Pasting items one after another in a specific order
- **Item:** A single piece of content in the stack (text, image, video, file, or URL)
