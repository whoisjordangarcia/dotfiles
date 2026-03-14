#!/bin/zsh
# Secrets injected from 1Password via `op inject`
# Template: .zshrc.sec.tpl → .zshrc.sec
#
# Add secrets using op:// references:
#   export MY_SECRET="{{ op://Vault/Item/field }}"
#
# Find your vault/item names with:
#   op vault list
#   op item list --vault "Personal"

# Example:
# export OPENAI_API_KEY="{{ op://Personal/OpenAI/api-key }}"
# export ANTHROPIC_API_KEY="{{ op://Personal/Anthropic/api-key }}"
