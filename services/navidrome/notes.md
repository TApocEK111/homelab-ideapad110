# Deployment
- via podman quadlet

# Data
- /srv/navidrome - app data
- ~/Music - music library

# Backup
- via rustic
- /srv/navidrome
- maybe backup the list of songs not the files itself

# Important for permissions
- UserNS=keep-id allows the inside non root user to be compatible with my outside user
