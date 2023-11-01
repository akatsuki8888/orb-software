# orb-short-lived-token-daemon
orb-short-lived-token-daemon repository

## Busctl commands
To fetch the auth token from the command line via dbus from the command line, run the following:
```
busctl call --address=unix:path=/tmp/worldcoin_bus_socket org.worldcoin.AuthTokenManager1 /org/worldcoin/AuthTokenManager1 org.freedesktop.DBus.Properties Get ss "org.worldcoin.AuthTokenManager1" "Token"
```
