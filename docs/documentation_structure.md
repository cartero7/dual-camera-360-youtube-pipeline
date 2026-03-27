# Documentation Structure

This document proposes a reusable structure for the project documentation site.

## Design System

Use the same visual system across every page:

- background: `#0B0F14` or equivalent near-black
- primary text: soft white
- secondary text: muted gray
- links: restrained professional blue
- typography: clean sans-serif, light-to-regular weights
- layout: left-aligned content inside a centered documentation-width container
- separators: thin horizontal rules between major sections
- visual style: minimal, technical, no heavy cards or marketing language

Recommended page shell:

- eyebrow label
- page title
- short technical introduction
- thin separator
- section blocks with consistent spacing
- small footer note when useful

## Overview

Recommended sections:

- Purpose
- System Summary
- Main Pipeline
- Repository Layout
- Quick Start
- Links to Detailed Docs

## Architecture

Recommended sections:

- High-Level Flow
- Inputs
- Processing Stages
- Output Paths
- Runtime State
- Failure and Recovery Model

## Deployment

Recommended sections:

- Requirements
- Installation
- Environment Configuration
- systemd Service Setup
- First Start
- Verification Checklist

## API

Recommended sections:

- Command-Line Interface
- Main Commands
- Environment Variables
- Input and Output Files
- Exit Conditions

## Operations

Recommended sections:

- Normal Operation
- Logs
- Runtime State Files
- Restart Behavior
- Scheduled Recycling
- Monitoring Recommendations

## Troubleshooting

Recommended sections:

- Common Failure Modes
- RTSP Connectivity Issues
- YouTube Ingest Issues
- Recording Issues
- Lock and Process Conflicts
- Useful Diagnostic Commands

## Credits & License

Recommended sections:

- System Design & Development
- Institution / Team
- Contact
- License
- Third-Party License Note

## Visual Consistency Rules

To keep the documentation coherent:

- keep titles large and concise
- keep introductions short and technical
- use the same section spacing on every page
- use the same link color and divider style everywhere
- avoid large visual jumps between pages
- keep pages readable without decorative UI
