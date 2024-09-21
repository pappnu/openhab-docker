# openHAB Docker

## Setup

Run with (assuming you have a user and a group named openhab)
```sh
USER_ID="$(id -u openhab)" GROUP_ID="$(id -g openhab)" docker compose up -d
```

Enter the Mosquitto container
```sh
docker exec -it <mosquitto_container_id> bash
```
and create a new user
```
mosquitto_passwd -c /mosquitto/config/password.txt <username>
```

Use `mosquitto` as broker "address" when connecting Mosquitto to openHAB.