#!/bin/zsh

# Create a new key with the Github email
ssh-keygen -t ed25519 -f "~/.ssh/id_ed25519" -C "suyash10581108@gmail.com"

# Start the ssh-agent in the background
eval "$(ssh-agent -s)"

# Add the private key to ssh-agent
ssh-add ~/.ssh/id_ed25519

# Remember to add the .pub file to Github
echo "Add the .pub file to Github now"
