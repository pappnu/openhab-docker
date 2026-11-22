#!/bin/bash
set -e

# https://community.openhab.org/t/user-creation-management-on-initial-start-of-openhab-on-docker-kubernetes/141654/12
# Ensure that the openhab user is used as otherwise some files receive wrong ownership and the main instance of
# openHAB fails to start at the end to the Docker entrypoint
/bin/bash -c "su-exec openhab /openhab/runtime/bin/start"
sleep 40
# Explicitly install ESPHome binding for the Native API, since it sometimes doesn't survive Docker container updates
sshpass -p habopen ssh -o StrictHostKeyChecking=no -p 8101 openhab@localhost "openhab:addons install marketplace:146849"
# Show INFO level log messages from openhab-heating-optimizer
sshpass -p habopen ssh -o StrictHostKeyChecking=no -p 8101 openhab@localhost "log:set INFO openhab.heating.optimizer"
/bin/bash -c "su-exec openhab /openhab/runtime/bin/stop"
sleep 40

# Forcibly clear cache as the JavaScript engine or the heating optimizer addon frequently get
# stuck after even just a patch level update of openHAB
rm -rf /openhab/userdata/tmp/*
rm -rf /openhab/userdata/cache/*